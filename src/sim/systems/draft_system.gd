class_name DraftSystem
extends RefCounted
## Patch draft trigger, seeded offers and the pick (GDD 02 section 10; M4-15).
## Schedule: the first draft ends wave `draft_first_wave` (10), then every `draft_interval` (10) waves up to
## `draft_interval_after` (50), then every `draft_interval_late` (25): 10, 20, 30, 40, 50, 75, 100, ...
## Same in TIMED and PURGE (Q74). A config with no patch defs has no draft.
## Offers: `draft_offer_count` distinct patches from `world.rng_draft` (one float and one index per slot, so the
## stream use is fixed). Slot mix: `draft_mix_gamble` gamble, the rest standard (the weapon-system share, 15% in
## the GDD, is folded into standard until weapon systems exist, so 85/15). A patch at max picks is never offered;
## an empty category falls back to the other one; fewer eligible patches than slots shrinks the offer; none
## eligible: no draft. No reroll. The draft stays open until `pick` (via `SimWorld.command_pick`).


## True when the end of wave `w` opens a draft.
static func is_draft_wave(t: SimTuning, w: int) -> bool:
	var first: int = t.draft_first_wave
	if first <= 0 or w < first:
		return false
	if w <= t.draft_interval_after:
		return t.draft_interval > 0 and (w - first) % t.draft_interval == 0
	return t.draft_interval_late > 0 and (w - t.draft_interval_after) % t.draft_interval_late == 0


## Waves until the next draft end counted from `w` (0 = the end of wave `w` itself opens one); -1 if none ever.
static func waves_until(t: SimTuning, w: int) -> int:
	for k: int in range(0, 10000):
		if is_draft_wave(t, w + k):
			return k
	return -1


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
	world.events.push(SimEventKind.DRAFT_OPENED, ending, offers.size())


## Patch indices of one draft, drawn from `world.rng_draft`.
static func roll_offers(world: SimWorld) -> PackedInt32Array:
	var t: SimTuning = world.config.tuning
	var standard: PackedInt32Array = PackedInt32Array()
	var gamble: PackedInt32Array = PackedInt32Array()
	var defs: Array[PatchDef] = world.config.patches
	for i: int in defs.size():
		if world.patches.qty(i) >= defs[i].max_picks:
			continue
		var failed: bool = gamble.append(i) if defs[i].is_gamble() else standard.append(i)
		if failed:
			push_error("DraftSystem: append failed")
	var out: PackedInt32Array = PackedInt32Array()
	var slots: int = mini(t.draft_offer_count, standard.size() + gamble.size())
	for _slot: int in slots:
		var r: float = world.rng_draft.next_float()
		# r < gamble: gamble; then standard; the remaining weapon-system share is folded into standard.
		var want_gamble: bool = r < t.draft_mix_gamble
		var pool: PackedInt32Array = gamble if want_gamble else standard
		if pool.is_empty():
			pool = standard if want_gamble else gamble
		var k: int = world.rng_draft.range_int(0, pool.size() - 1)
		if out.append(pool[k]):
			push_error("DraftSystem: append failed")
		pool.remove_at(k)
	return out


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
