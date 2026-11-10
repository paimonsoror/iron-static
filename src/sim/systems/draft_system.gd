class_name DraftSystem
extends RefCounted
## Patch draft trigger, seeded offers, the reroll and the pick (GDD 02 section 10; M4-15, R1-04).
## Schedule: drafts end waves 5, 10, 15, 20 (`draft_first_wave` 5, every `draft_interval` 5 up to
## `draft_interval_after` 20), then every `draft_interval_mid` (10) up to `draft_interval_mid_after` (50), then every
## `draft_interval_late` (25): 5, 10, 15, 20, 30, 40, 50, 75, 100, ... Same in TIMED and PURGE (Q74). A config with
## no patch defs has no draft.
## Offers (R1-04): one card per family in `FAMILIES` order (ARMS, CHASSIS, SYSTEMS), from `world.rng_draft`. Per
## family slot: one float (gamble roll against `draft_mix_gamble`) and one index into that family's eligible standard
## patches. A slot that rolled a gamble draws one eligible gamble (index draw) whose own family slot it then replaces.
## A family with no eligible standard patch (all maxed) is filled from the other families' leftovers; no leftover:
## the slot is skipped (fewer cards; none at all: no draft). A patch at max picks is never offered. A reroll
## (`draft_rerolls` per draft, `command_reroll`) redraws all cards from the same stream.
## The draft stays open until `pick` (via `SimWorld.command_pick`).

const FAMILIES: PackedStringArray = ["arms", "chassis", "systems"]


## True when the end of wave `w` opens a draft.
static func is_draft_wave(t: SimTuning, w: int) -> bool:
	var first: int = t.draft_first_wave
	if first <= 0 or w < first:
		return false
	if w <= t.draft_interval_after:
		return t.draft_interval > 0 and (w - first) % t.draft_interval == 0
	if w <= t.draft_interval_mid_after:
		return t.draft_interval_mid > 0 and (w - t.draft_interval_after) % t.draft_interval_mid == 0
	return t.draft_interval_late > 0 and (w - t.draft_interval_mid_after) % t.draft_interval_late == 0


## Waves until the next draft end counted from `w` (0 = the end of wave `w` itself opens one); -1 if none ever.
static func waves_until(t: SimTuning, w: int) -> int:
	for k: int in range(0, 10000):
		if is_draft_wave(t, w + k):
			return k
	return -1


## Waves from the current wave of `world` to the end of the next draft wave (0 = the end of this wave opens one); -1
## when the config has no patches or no draft is ever due. Read-only (M4-19; moved here from SimWorld in R1-04).
static func waves_until_draft(world: SimWorld) -> int:
	if world.config.patches.is_empty():
		return -1
	return waves_until(world.config.tuning, world.wave)


## Called by WaveEndSystem at the end of wave `ending` (after its steps 6-8). Opens the draft when due.
static func check(world: SimWorld, ending: int) -> void:
	if world.config.patches.is_empty() or not world.cinder.alive:
		return
	if not is_draft_wave(world.config.tuning, ending):
		return
	var offers: PackedInt32Array = roll_offers(world)
	if offers.is_empty():
		return
	var d: DraftState = world.draft
	d.open = true
	d.wave = ending
	d.offers = offers
	d.rerolls_used = 0
	world.events.push(SimEventKind.DRAFT_OPENED, ending, offers.size())


## Patch indices of one draft (ARMS, CHASSIS, SYSTEMS order, skipped families omitted), drawn from `world.rng_draft`.
static func roll_offers(world: SimWorld) -> PackedInt32Array:
	var t: SimTuning = world.config.tuning
	var defs: Array[PatchDef] = world.config.patches
	var standard: Array[PackedInt32Array] = []
	for _f: int in FAMILIES.size():
		standard.append(PackedInt32Array())
	var gamble: PackedInt32Array = PackedInt32Array()
	for i: int in defs.size():
		if world.patches.qty(i) >= defs[i].max_picks:
			continue
		if defs[i].is_gamble():
			if gamble.append(i):
				push_error("DraftSystem: append failed")
		else:
			var fam: int = family_slot(defs[i])
			if fam >= 0 and standard[fam].append(i):
				push_error("DraftSystem: append failed")
	var cards: PackedInt32Array = PackedInt32Array()
	var rolled: PackedByteArray = PackedByteArray()
	for f: int in FAMILIES.size():
		var r: float = world.rng_draft.next_float()
		var pool: PackedInt32Array = standard[f]
		var k: int = world.rng_draft.range_int(0, maxi(pool.size() - 1, 0))
		var failed: bool = cards.append(pool[k] if not pool.is_empty() else -1)
		failed = rolled.append(1 if r < t.draft_mix_gamble else 0) or failed
		if failed:
			push_error("DraftSystem: append failed")
	_apply_gambles(world, cards, rolled, gamble)
	_fill_empty(world, cards, standard)
	var out: PackedInt32Array = PackedInt32Array()
	for c: int in cards:
		if c >= 0 and out.size() < t.draft_offer_count and out.append(c):
			push_error("DraftSystem: append failed")
	return out


## Family slot (index into `FAMILIES`) of `def`, -1 for an unknown family.
static func family_slot(def: PatchDef) -> int:
	return FAMILIES.find(def.family)


## Each rolled slot draws one gamble whose family slot does not already hold a gamble and puts it there.
static func _apply_gambles(
	world: SimWorld, cards: PackedInt32Array, rolled: PackedByteArray, gamble: PackedInt32Array
) -> void:
	var defs: Array[PatchDef] = world.config.patches
	var held: PackedByteArray = PackedByteArray()
	if held.resize(FAMILIES.size()):
		push_error("DraftSystem: resize failed")
	for f: int in FAMILIES.size():
		if rolled[f] == 0:
			continue
		var usable: PackedInt32Array = PackedInt32Array()
		for g: int in gamble:
			var fam: int = family_slot(defs[g])
			if fam >= 0 and held[fam] == 0 and usable.append(g):
				push_error("DraftSystem: append failed")
		if usable.is_empty():
			continue
		var pick_at: int = world.rng_draft.range_int(0, usable.size() - 1)
		var chosen: int = usable[pick_at]
		var slot: int = family_slot(defs[chosen])
		cards[slot] = chosen
		held[slot] = 1
		gamble.remove_at(gamble.find(chosen))


## A slot with no card takes a random leftover standard patch of the other families (none left: stays empty).
static func _fill_empty(world: SimWorld, cards: PackedInt32Array, standard: Array[PackedInt32Array]) -> void:
	for f: int in FAMILIES.size():
		if cards[f] >= 0:
			continue
		var spare: PackedInt32Array = PackedInt32Array()
		for fam: int in FAMILIES.size():
			for i: int in standard[fam]:
				if not cards.has(i) and spare.append(i):
					push_error("DraftSystem: append failed")
		if spare.is_empty():
			return
		cards[f] = spare[world.rng_draft.range_int(0, spare.size() - 1)]


## Rerolls all cards of the open draft once per `draft_rerolls`. False (no change) when none is open or the allowance
## is used up. The new offers come from the same `rng_draft` stream, so a replay reproduces them.
static func reroll(world: SimWorld) -> bool:
	var d: DraftState = world.draft
	if not d.open or d.rerolls_used >= world.config.tuning.draft_rerolls:
		return false
	var offers: PackedInt32Array = roll_offers(world)
	if offers.is_empty():
		return false
	d.offers = offers
	d.rerolls_used += 1
	return true


## Takes offer `slot`: counts the pick, closes the draft. False (no change) when no draft is open or the slot is
## out of range.
static func pick(world: SimWorld, slot: int) -> bool:
	var d: DraftState = world.draft
	if not d.open or slot < 0 or slot >= d.offers.size():
		return false
	var index: int = d.offers[slot]
	if not PatchEffects.pick(world, index):
		return false
	d.close()
	world.events.push(SimEventKind.PATCH_PICKED, index, world.patches.qty(index))
	return true
