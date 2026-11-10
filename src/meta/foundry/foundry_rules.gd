class_name FoundryRules
extends RefCounted
## Foundry formulas as pure static functions (GDD 05 sections 1.1-1.5, M3-06). Costs are BigNum: exact
## integers (plain float math, below 1e15) for everything the MVP reaches, BigNum `pow_float` above that
## so F = 200 stays finite.
## The Foundry soft cap (R1-02, review G-06, Q89; GDD 05 section 1.5) and the Foundry milestone are DATA: rows of
## data/sim_constants.csv read through a `SimTuning` (`foundry_cap_k`, `foundry_cap_min`, `foundry_over_cap_mult`,
## `foundry_milestone_step`, `foundry_milestone_mult`). Every function that needs one takes `t`. FO-3 had them as
## constants here because the meta layer had no tuning; `FoundryService` now carries one (default
## `SimConfigLoader.load_tuning()`), so there is one source and no code constant left except the ones below.

const EXACT_LIMIT: float = 1.0e15
const SUM_STEP_CAP: int = 300  ## total_cost sums at most this many levels exactly; more uses the closed form
## `recommended` considers a Type D row near a milestone when it is at most this many levels away (a UI glow rule, the
## same distance as `UpgradeRowModel.MILESTONE_GLOW_LEVELS`; not a balance number).
const NEAR_MILESTONE: int = 3
## Float epsilon of `wave_cap` (the floor of an exact product such as 0.6 * 5).
const CAP_EPS: float = 1.0e-9
## "No best-wave limit": tools and the journey probe lift the soft cap with this limit (every level at a normal price).
const NO_LIMIT: int = 1 << 30


## `ceil(fc0 * fg ^ level)` data for the step level -> level + 1.
static func cost(def: FoundryDef, level: int) -> BigNum:
	var lvl: int = maxi(level, 0)
	var v: float = def.fc0 * pow(def.fg, float(lvl))
	if v < EXACT_LIMIT:
		return BigNum.from_float(ceilf(v))
	return BigNum.from_float(def.fc0).mul(BigNum.from_float(def.fg).pow_float(float(lvl))).floor_value()


## Level cap: Type D `f_cap`; Type C the generic rule `StatResolver.foundry_cap` of the matching run row.
static func level_cap(def: FoundryDef, run_def: RunUpgradeDef) -> int:
	if def.kind == "C" and run_def != null:
		return StatResolver.foundry_cap(run_def)
	return def.f_cap


## Soft cap of the Foundry (TIMED sector 1): a level whose index (the level being bought from) is at or above
## `max(foundry_cap_min, floor(foundry_cap_k * best_wave))` costs `foundry_over_cap_mult` times more. Never a lock.
static func wave_cap(best_wave: int, t: SimTuning) -> int:
	return maxi(t.foundry_cap_min, floori(t.foundry_cap_k * float(maxi(best_wave, 0)) + CAP_EPS))


## Smallest best wave at which `wave_cap` is at least `target_level`, i.e. the wave from which buying the level whose
## index is `target_level - 1` is no longer over the cap (the N of "x3 COST UNTIL WAVE N").
static func wave_for_level(target_level: int, t: SimTuning) -> int:
	if target_level <= t.foundry_cap_min:
		return 0
	var w: int = maxi(ceili(float(target_level) / t.foundry_cap_k) - 2, 0)
	while wave_cap(w, t) < target_level:
		w += 1
	return w


## Cost of the step `level` -> `level + 1` with the soft cap at `limit`: `cost(def, level)`, times
## `foundry_over_cap_mult` when `level >= limit`. The first version is flat; compounding (`mult ^ levels_over`) is an
## option the journey targets can ask for (R1-02).
static func step_cost(def: FoundryDef, level: int, limit: int, t: SimTuning) -> BigNum:
	var base: BigNum = cost(def, level)
	if level >= limit:
		return base.mul_float(t.foundry_over_cap_mult).floor_value()
	return base


## Type D: `Curves.foundry_mult`. Type C: the starting stat delta `step * F` (0 without `run_def`).
static func multiplier(def: FoundryDef, level: int, run_def: RunUpgradeDef = null, t: SimTuning = null) -> float:
	if def.kind == "D":
		return Curves.foundry_mult(maxi(level, 0), def.f, t)
	if run_def == null:
		return 0.0
	return run_def.step * float(clampi(level, 0, level_cap(def, run_def)))


## Stat value of a run that starts at run level 0 with Foundry level `level` (no frame, no externals).
static func start_value(def: FoundryDef, run_def: RunUpgradeDef, level: int, t: SimTuning = null) -> float:
	return StatResolver.value_at(run_def, 0, level, def.f, 1.0, 0.0, t)


## The next multiple of the Foundry milestone step above `level` (Type D milestone).
static func next_milestone(level: int, t: SimTuning) -> int:
	var step: int = Curves.foundry_step(t)
	return (floori(float(maxi(level, 0)) / float(step)) + 1) * step


## Levels to the next Foundry milestone (x1.75 every 25 with the shipped data): 1 at F24, 25 at F25. -1 for a Type C
## `def` (no milestones).
static func levels_to_milestone(level: int, def: FoundryDef, t: SimTuning) -> int:
	if def != null and def.kind == "C":
		return -1
	return next_milestone(level, t) - maxi(level, 0)


## Cost of buying `count` levels starting at `level` with the soft cap at `limit`: the exact sum of the step costs (at
## most SUM_STEP_CAP steps; beyond that the closed form fc0 * fg^F * (fg^n - 1) / (fg - 1) per segment, below and at or
## above the limit; documented fallback).
static func total_cost(def: FoundryDef, level: int, count: int, limit: int, t: SimTuning) -> BigNum:
	var total: BigNum = BigNum.zero()
	var steps: int = mini(maxi(count, 0), SUM_STEP_CAP)
	for i: int in steps:
		total = total.add(step_cost(def, level + i, limit, t))
	var rest: int = count - steps
	if rest > 0:
		var start: int = level + steps
		var below: int = clampi(limit - start, 0, rest)
		total = total.add(_geometric(def, start, below))
		total = total.add(_geometric(def, start + below, rest - below).mul_float(t.foundry_over_cap_mult))
	return total


## Closed form of `count` consecutive costs from `level` (no soft cap).
static func _geometric(def: FoundryDef, level: int, count: int) -> BigNum:
	if count <= 0:
		return BigNum.zero()
	var first: BigNum = cost(def, level)
	var growth: BigNum = BigNum.from_float(def.fg).pow_float(float(count)).sub_floor0(BigNum.one())
	return first.mul(growth).mul_float(1.0 / (def.fg - 1.0))


## Most levels (at most `cap_count`) that `data` pays for, buying one after the other, with the soft cap at `limit`.
static func max_affordable(def: FoundryDef, level: int, data: BigNum, cap_count: int, limit: int, t: SimTuning) -> int:
	var left: BigNum = data
	var bought: int = 0
	while bought < cap_count:
		var c: BigNum = step_cost(def, level + bought, limit, t)
		if not covers(left, c):
			break
		left = left.sub_floor0(c)
		bought += 1
	return bought


## Index of the "Recommended" row or -1 (Q58, impl): among Type D rows not maxed with at most NEAR_MILESTONE levels to
## the next milestone the cheapest next level; else the cheapest affordable row; else none. Rows below the soft cap
## are preferred (R1-02): rows at or above it (x3 cost) are only recommended when no row below the cap qualifies.
## Ties go to the first row.
static func recommended(rows: Array[FoundryRowView]) -> int:
	var below: int = _recommended(rows, false)
	if below >= 0:
		return below
	return _recommended(rows, true)


static func _recommended(rows: Array[FoundryRowView], allow_over: bool) -> int:
	var best: int = -1
	for i: int in rows.size():
		var r: FoundryRowView = rows[i]
		if r.maxed or (r.over_limit and not allow_over):
			continue
		var near: bool = r.kind == "D" and r.levels_to_milestone <= NEAR_MILESTONE
		if near and (best < 0 or r.cost.lt(rows[best].cost)):
			best = i
	if best >= 0:
		return best
	for i: int in rows.size():
		var r: FoundryRowView = rows[i]
		if r.maxed or (r.over_limit and not allow_over):
			continue
		if r.affordable and (best < 0 or r.cost.lt(rows[best].cost)):
			best = i
	return best


## Foundry levels aligned with `upgrades` (0 for rows without a Foundry row), each clamped to 0..cap.
static func aligned_levels(
	upgrades: Array[RunUpgradeDef], defs: Array[FoundryDef], levels: Dictionary
) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var n: int = out.resize(upgrades.size())
	if n != OK:
		return out
	for i: int in upgrades.size():
		var def: FoundryDef = find_def(defs, upgrades[i].id)
		if def != null:
			var raw: Variant = levels.get(def.id, 0)
			var lvl: int = raw if raw is int else 0
			out[i] = clampi(lvl, 0, level_cap(def, upgrades[i]))
	return out


## Per-level factor `f` aligned with `upgrades` (0 for Type C rows and rows without a Foundry row).
static func aligned_f(upgrades: Array[RunUpgradeDef], defs: Array[FoundryDef]) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	var n: int = out.resize(upgrades.size())
	if n != OK:
		return out
	for i: int in upgrades.size():
		var def: FoundryDef = find_def(defs, upgrades[i].id)
		if def != null:
			out[i] = def.f
	return out


static func find_def(defs: Array[FoundryDef], id: String) -> FoundryDef:
	for d: FoundryDef in defs:
		if d.id == id:
			return d
	return null


static func find_run_def(upgrades: Array[RunUpgradeDef], id: String) -> RunUpgradeDef:
	for u: RunUpgradeDef in upgrades:
		if u.id == id:
			return u
	return null


## `have >= need` with a 1e-12 relative tolerance: BigNum keeps a float mantissa, so 25 + 23 can land a hair
## under 48 and an exact compare would refuse a purchase the player can afford.
static func covers(have: BigNum, need: BigNum) -> bool:
	return have.mul_float(1.0 + 1.0e-12).ge(need)
