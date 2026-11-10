class_name FoundryService
extends RefCounted
## Foundry behavior on a PlayerProfile (M3-06): row views for the UI, buying, affordability counts and the
## Power Rating preview. Pure: defs come in through the constructor (`SimConfigLoader.load_foundry_defs()`
## builds them from the generated resources). Signature note (impl): the spec's `rows(profile, data_defs,
## upgrades)` takes the defs once in `_init` instead of on every call.

var defs: Array[FoundryDef] = []
var upgrades: Array[RunUpgradeDef] = []
## The tuning the Foundry rules read (soft cap rows, milestone rows; R1-02): one private copy of data/sim_constants.csv,
## replaceable by a tool that measures a candidate value (the journey tool sets its `--set sim.*` copy here).
var tuning: SimTuning = null
## False lifts the best-wave soft cap (every level at the normal price) so a tool can spend Data on a fresh profile
## (journey probe); the game never sets it.
var wave_cap_enabled: bool = true


func _init(
	foundry_defs: Array[FoundryDef], run_upgrades: Array[RunUpgradeDef], foundry_tuning: SimTuning = null
) -> void:
	defs = foundry_defs
	upgrades = run_upgrades
	tuning = foundry_tuning if foundry_tuning != null else SimConfigLoader.load_tuning()


## One view per Foundry row in display (CSV) order, with the Recommended flag set.
func rows(profile: PlayerProfile) -> Array[FoundryRowView]:
	var out: Array[FoundryRowView] = []
	for def: FoundryDef in defs:
		out.append(_row(profile, def))
	var rec: int = FoundryRules.recommended(out)
	if rec >= 0:
		out[rec].recommended = true
	return out


## Buys up to `count` levels of row `id`: never above the row cap, never above what `data` pays (partial buys
## allowed). Levels at or above the soft cap are bought at the multiplied price, never refused (R1-02). Mutates
## `profile.data` and `profile.foundry` together. Returns the levels bought (0 = rejected).
func buy(profile: PlayerProfile, id: String, count: int) -> int:
	var def: FoundryDef = FoundryRules.find_def(defs, id)
	if def == null or count <= 0:
		return 0
	var level: int = profile.foundry_level(id)
	var limit: int = _limit(profile)
	var room: int = FoundryRules.level_cap(def, FoundryRules.find_run_def(upgrades, id)) - level
	if room <= 0:
		return 0
	var n: int = FoundryRules.max_affordable(def, level, profile.data, mini(count, room), limit, tuning)
	if n <= 0:
		return 0
	profile.data = profile.data.sub_floor0(FoundryRules.total_cost(def, level, n, limit, tuning))
	profile.set_foundry_level(id, level + n)
	return n


## Rows whose next level is affordable now at the normal price (the Results / Home badge). (impl) A row over the soft
## cap does not count: the badge should not nudge towards the x3 price.
func affordable_count(profile: PlayerProfile) -> int:
	var n: int = 0
	for r: FoundryRowView in rows(profile):
		if r.affordable and not r.over_limit:
			n += 1
	return n


## Power Rating of a zero-run-level start now (x) and after one more level of row `id` (y).
func power_rating_preview(profile: PlayerProfile, id: String) -> Vector2:
	var now_levels: Dictionary = profile.foundry.duplicate()
	var next_levels: Dictionary = profile.foundry.duplicate()
	next_levels[id] = profile.foundry_level(id) + 1
	return Vector2(_rating(now_levels), _rating(next_levels))


## Level from which a purchase costs more: the soft cap at the profile best wave, or none for a tool.
func _limit(profile: PlayerProfile) -> int:
	if not wave_cap_enabled:
		return FoundryRules.NO_LIMIT
	return FoundryRules.wave_cap(profile.best_wave_s1(), tuning)


func _rating(levels: Dictionary) -> float:
	var stats: StatBlock = StatBlock.from_resolver(
		upgrades,
		PackedInt32Array(),
		FoundryRules.aligned_levels(upgrades, defs, levels),
		FoundryRules.aligned_f(upgrades, defs),
		null,
		tuning
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
	v.limit = _limit(profile)
	v.milestone_step = Curves.foundry_step(tuning)
	v.milestone_mult = Curves.foundry_milestone_mult(tuning)
	v.mult_now = FoundryRules.multiplier(def, v.level, run_def, tuning)
	v.mult_next = v.mult_now if v.maxed else FoundryRules.multiplier(def, v.level + 1, run_def, tuning)
	if run_def != null:
		v.start_now = FoundryRules.start_value(def, run_def, v.level, tuning)
		v.start_next = v.start_now if v.maxed else FoundryRules.start_value(def, run_def, v.level + 1, tuning)
	v.delta = v.start_next - v.start_now
	if v.maxed:
		return v
	v.base_cost = FoundryRules.cost(def, v.level)
	v.cost = FoundryRules.step_cost(def, v.level, v.limit, tuning)
	v.levels_to_milestone = FoundryRules.levels_to_milestone(v.level, def, tuning)
	v.over_limit = v.level >= v.limit
	v.over_mult = tuning.foundry_over_cap_mult
	if v.over_limit:
		v.next_wave = FoundryRules.wave_for_level(v.level + 1, tuning)
	else:
		v.room_below_limit = mini(v.limit, v.cap) - v.level
	v.affordable = FoundryRules.covers(profile.data, v.cost)
	if v.affordable:
		v.afford_in_minutes = 0.0
	elif profile.farm_rate_1x > 0.0:
		v.afford_in_minutes = v.cost.sub_floor0(profile.data).to_float() / profile.farm_rate_1x
	return v
