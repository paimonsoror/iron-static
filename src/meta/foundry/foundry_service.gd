class_name FoundryService
extends RefCounted
## Foundry behavior on a PlayerProfile (M3-06): row views for the UI, buying, affordability counts and the
## Power Rating preview. Pure: defs come in through the constructor (`SimConfigLoader.load_foundry_defs()`
## builds them from the generated resources). Signature note (impl): the spec's `rows(profile, data_defs,
## upgrades)` takes the defs once in `_init` instead of on every call.

var defs: Array[FoundryDef] = []
var upgrades: Array[RunUpgradeDef] = []
## False lifts the best-wave level cap (FO-3) so a tool can spend Data on a fresh profile (journey probe); the game
## never sets it.
var wave_cap_enabled: bool = true


func _init(foundry_defs: Array[FoundryDef], run_upgrades: Array[RunUpgradeDef]) -> void:
	defs = foundry_defs
	upgrades = run_upgrades


## One view per Foundry row in display (CSV) order, with the Recommended flag set.
func rows(profile: PlayerProfile) -> Array[FoundryRowView]:
	var out: Array[FoundryRowView] = []
	for def: FoundryDef in defs:
		out.append(_row(profile, def))
	var rec: int = FoundryRules.recommended(out)
	if rec >= 0:
		out[rec].recommended = true
	return out


## Buys up to `count` levels of row `id`: never above the row cap or the best-wave limit (a profile already above
## the limit keeps its levels and buys nothing), never above what `data` pays (partial buys allowed). Mutates
## `profile.data` and `profile.foundry` together. Returns the levels bought (0 = rejected).
func buy(profile: PlayerProfile, id: String, count: int) -> int:
	var def: FoundryDef = FoundryRules.find_def(defs, id)
	if def == null or count <= 0:
		return 0
	var level: int = profile.foundry_level(id)
	var limit: int = _limit(profile, def, FoundryRules.find_run_def(upgrades, id))
	var room: int = limit - level
	if room <= 0:
		return 0
	var n: int = FoundryRules.max_affordable(def, level, profile.data, mini(count, room))
	if n <= 0:
		return 0
	profile.data = profile.data.sub_floor0(FoundryRules.total_cost(def, level, n))
	profile.set_foundry_level(id, level + n)
	return n


## Rows whose next level is affordable now (the Results button badge).
func affordable_count(profile: PlayerProfile) -> int:
	var n: int = 0
	for r: FoundryRowView in rows(profile):
		if r.affordable:
			n += 1
	return n


## Power Rating of a zero-run-level start now (x) and after one more level of row `id` (y).
func power_rating_preview(profile: PlayerProfile, id: String) -> Vector2:
	var now_levels: Dictionary = profile.foundry.duplicate()
	var next_levels: Dictionary = profile.foundry.duplicate()
	next_levels[id] = profile.foundry_level(id) + 1
	return Vector2(_rating(now_levels), _rating(next_levels))


func _limit(profile: PlayerProfile, def: FoundryDef, run_def: RunUpgradeDef) -> int:
	if not wave_cap_enabled:
		return FoundryRules.level_cap(def, run_def)
	return FoundryRules.level_limit(def, run_def, profile.best_wave_s1())


func _rating(levels: Dictionary) -> float:
	var stats: StatBlock = StatBlock.from_resolver(
		upgrades,
		PackedInt32Array(),
		FoundryRules.aligned_levels(upgrades, defs, levels),
		FoundryRules.aligned_f(upgrades, defs)
	)
	return PowerRating.power_rating(stats)


func _row(profile: PlayerProfile, def: FoundryDef) -> FoundryRowView:
	var run_def: RunUpgradeDef = FoundryRules.find_run_def(upgrades, def.id)
	var v: FoundryRowView = FoundryRowView.new()
	v.id = def.id
	v.kind = def.kind
	v.cap = FoundryRules.level_cap(def, run_def)
	v.level = mini(profile.foundry_level(def.id), v.cap)
	v.maxed = v.level >= v.cap
	v.limit = _limit(profile, def, run_def)
	v.mult_now = FoundryRules.multiplier(def, v.level, run_def)
	v.mult_next = v.mult_now if v.maxed else FoundryRules.multiplier(def, v.level + 1, run_def)
	if run_def != null:
		v.start_now = FoundryRules.start_value(def, run_def, v.level)
		v.start_next = v.start_now if v.maxed else FoundryRules.start_value(def, run_def, v.level + 1)
	v.delta = v.start_next - v.start_now
	if v.maxed:
		return v
	v.cost = FoundryRules.cost(def, v.level)
	v.levels_to_milestone = FoundryRules.levels_to_milestone(v.level, def)
	if v.level >= v.limit:
		v.capped = true
		v.next_wave = FoundryRules.wave_for_level(v.level + 1)
		return v
	v.affordable = FoundryRules.covers(profile.data, v.cost)
	if v.affordable:
		v.afford_in_minutes = 0.0
	elif profile.farm_rate_1x > 0.0:
		v.afford_in_minutes = v.cost.sub_floor0(profile.data).to_float() / profile.farm_rate_1x
	return v
