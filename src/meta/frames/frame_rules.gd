class_name FrameRules
extends RefCounted
## Frame rules (M3-23, design 11 sections 1.1, 1.3, 3). Pure static: unlocks at banking, selection and the
## stat-comparison card model. Only `implemented` frames are ever unlocked or listed (M6 rows stay hidden).
##
## Public API (the bay M3-29, title M3-28/30, Home M3-15 and Results M3-17 call these):
##   static load_defs() -> Array[FrameDef]               (generated table, CSV order)
##   static find_def(defs, id) -> FrameDef               (null when unknown)
##   static is_unlocked(profile, id) -> bool
##   static unlockable(defs, best_wave) -> Array[String]
##   static apply_unlocks(profile, defs) -> Array[String]  (newly unlocked ids, from best_wave_s1)
##   static bank(profile, summary, defs) -> Array[String]  (bank_run + apply_unlocks; [] when not banked)
##   static select(profile, id) -> bool
##   static selected_id(profile, defs) -> String         (the selected frame, vanguard when invalid)
##   static cards(profile, defs, foundry, reference_id = "") -> Array[FrameCard]

const FRAME_TABLE_PATH: String = "res://src/data_gen/frame_table.tres"
const DEFAULT_FRAME: String = "vanguard"
const KEY_LOCKED: String = "frame.locked_wave"
const KEY_PROGRESS: String = "frame.progress"
const KEY_CHIP: String = "frame.unlocked_chip"


## The frames of the generated table in CSV order (shared resources: treat as read-only).
static func load_defs() -> Array[FrameDef]:
	var table: FrameTable = load(FRAME_TABLE_PATH)
	return table.defs


static func find_def(defs: Array[FrameDef], id: String) -> FrameDef:
	for def: FrameDef in defs:
		if def.id == id:
			return def
	return null


static func is_unlocked(profile: PlayerProfile, id: String) -> bool:
	return profile.is_frame_unlocked(id)


## Ids of implemented frames whose threshold is at most `best_wave`, in CSV order.
static func unlockable(defs: Array[FrameDef], best_wave: int) -> Array[String]:
	var out: Array[String] = []
	for def: FrameDef in defs:
		if def.implemented and def.unlock_best_wave <= best_wave:
			out.append(def.id)
	return out


## Unlocks every frame the profile's sector 1 best wave now qualifies for. Returns the ids unlocked by this
## call (empty when nothing new), so a second call returns `[]`. Frames never lock again.
static func apply_unlocks(profile: PlayerProfile, defs: Array[FrameDef]) -> Array[String]:
	var fresh: Array[String] = []
	for id: String in unlockable(defs, profile.best_wave_s1()):
		if profile.unlock_frame(id):
			fresh.append(id)
	return fresh


## Banks a run and evaluates the frame unlocks (impl: lives here until `PlayerProfile.bank_run` may call it;
## the Results chip reads the returned ids). A rejected bank (old run id, debug run) unlocks nothing.
static func bank(profile: PlayerProfile, summary: RunSummary, defs: Array[FrameDef]) -> Array[String]:
	if not profile.bank_run(summary):
		return []
	return apply_unlocks(profile, defs)


## Selects an unlocked frame. False (nothing changes) otherwise.
static func select(profile: PlayerProfile, id: String) -> bool:
	return profile.select_frame(id)


## The selected frame id, falling back to vanguard when the stored one is not unlocked or not listed.
static func selected_id(profile: PlayerProfile, defs: Array[FrameDef]) -> String:
	var id: String = profile.frame_selected
	if profile.is_frame_unlocked(id) and find_def(defs, id) != null:
		return id
	return DEFAULT_FRAME


## One card per listed (implemented) frame in CSV order. Deltas and the Power Rating comparison are against
## `reference_id` (impl: empty = the selected frame, design 11 section 3; pass "vanguard" for a fixed base).
## The Power Rating uses the profile's Foundry levels (via the service's defs) and the frame mods.
static func cards(
	profile: PlayerProfile, defs: Array[FrameDef], foundry: FoundryService, reference_id: String = ""
) -> Array[FrameCard]:
	var sel: String = selected_id(profile, defs)
	var ref_def: FrameDef = find_def(defs, reference_id if not reference_id.is_empty() else sel)
	if ref_def == null:
		ref_def = find_def(defs, DEFAULT_FRAME)
	var ref_start: StatBlock = _stats(foundry, ref_def, {})
	var ref_pr: float = PowerRating.power_rating(_stats(foundry, ref_def, profile.foundry))
	var best: int = profile.best_wave_s1()
	var out: Array[FrameCard] = []
	for def: FrameDef in defs:
		if not def.implemented:
			continue
		var c: FrameCard = FrameCard.new()
		c.id = def.id
		c.name_key = def.name_key
		c.role_key = def.role_key
		c.passive_key = def.passive_key
		c.passive_desc_key = "frame.passive_desc." + def.id
		c.locked = not profile.is_frame_unlocked(def.id)
		c.selected = def.id == sel
		c.unlock_best_wave = def.unlock_best_wave
		c.best_wave = best
		if c.locked:
			c.condition_key = KEY_LOCKED
			c.progress_key = KEY_PROGRESS
		c.deltas = _deltas(ref_start, _stats(foundry, def, {}))
		c.power_rating = PowerRating.power_rating(_stats(foundry, def, profile.foundry))
		c.power_rating_delta = _pct(c.power_rating, ref_pr)
		out.append(c)
	return out


## Resolved start stats (run level 0) of a frame with the given Foundry level map.
static func _stats(foundry: FoundryService, def: FrameDef, levels: Dictionary) -> StatBlock:
	var mods: FrameMods = SimConfigLoader.frame_mods_from(def)
	return StatBlock.from_resolver(
		foundry.upgrades,
		PackedInt32Array(),
		FoundryRules.aligned_levels(foundry.upgrades, foundry.defs, levels),
		FoundryRules.aligned_f(foundry.upgrades, foundry.defs),
		mods.to_external(),
		foundry.tuning
	)


static func _deltas(ref: StatBlock, s: StatBlock) -> Dictionary:
	return {
		"hull": _pct(s.hull_integrity, ref.hull_integrity),
		"rate": _pct(s.cycle_rate, ref.cycle_rate),
		"damage": _pct(s.laser_output, ref.laser_output),
		"range": _pct(s.optic_range, ref.optic_range),
		"crit": _pct(s.crit_chance, ref.crit_chance),
		"repair": _pct(s.nano_repair, ref.nano_repair),
	}


## Percent change of `v` against `base` (0 when base is not positive).
static func _pct(v: float, base: float) -> float:
	if base <= 0.0:
		return 0.0
	return (v / base - 1.0) * 100.0
