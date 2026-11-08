class_name FoundryRules
extends RefCounted
## Foundry formulas as pure static functions (GDD 05 sections 1.1-1.4, M3-06). Costs are BigNum: exact
## integers (plain float math, below 1e15) for everything the MVP reaches, BigNum `pow_float` above that
## so F = 200 stays finite.

const EXACT_LIMIT: float = 1.0e15
const MILESTONE_STEP: int = 10  ## Curves.MILESTONE_FOUNDRY_STEP
const SUM_STEP_CAP: int = 300  ## total_cost sums at most this many levels exactly; more uses the closed form
## `recommended` considers a Type D row near a milestone when it is at most this many levels away.
const NEAR_MILESTONE: int = 3


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


## Type D: `Curves.foundry_mult`. Type C: the starting stat delta `step * F` (0 without `run_def`).
static func multiplier(def: FoundryDef, level: int, run_def: RunUpgradeDef = null) -> float:
	if def.kind == "D":
		return Curves.foundry_mult(maxi(level, 0), def.f)
	if run_def == null:
		return 0.0
	return run_def.step * float(clampi(level, 0, level_cap(def, run_def)))


## Stat value of a run that starts at run level 0 with Foundry level `level` (no frame, no externals).
static func start_value(def: FoundryDef, run_def: RunUpgradeDef, level: int) -> float:
	return StatResolver.value_at(run_def, 0, level, def.f)


## The next multiple of 10 above `level` (Type D milestone).
static func next_milestone(level: int) -> int:
	return (floori(float(maxi(level, 0)) / float(MILESTONE_STEP)) + 1) * MILESTONE_STEP


## Levels to the next x1.25 milestone: 1 at F9, 10 at F10. -1 for a Type C `def` (no milestones).
static func levels_to_milestone(level: int, def: FoundryDef = null) -> int:
	if def != null and def.kind == "C":
		return -1
	return next_milestone(level) - maxi(level, 0)


## Cost of buying `count` levels starting at `level`: the exact sum of per-level costs (at most
## SUM_STEP_CAP steps; beyond that the closed form fc0 * fg^F * (fg^n - 1) / (fg - 1), documented fallback).
static func total_cost(def: FoundryDef, level: int, count: int) -> BigNum:
	var total: BigNum = BigNum.zero()
	var steps: int = mini(maxi(count, 0), SUM_STEP_CAP)
	for i: int in steps:
		total = total.add(cost(def, level + i))
	var rest: int = count - steps
	if rest > 0:
		var first: BigNum = cost(def, level + steps)
		var growth: BigNum = BigNum.from_float(def.fg).pow_float(float(rest)).sub_floor0(BigNum.one())
		total = total.add(first.mul(growth).mul_float(1.0 / (def.fg - 1.0)))
	return total


## Most levels (at most `cap_count`) that `data` pays for, buying one after the other.
static func max_affordable(def: FoundryDef, level: int, data: BigNum, cap_count: int) -> int:
	var left: BigNum = data
	var bought: int = 0
	while bought < cap_count:
		var c: BigNum = cost(def, level + bought)
		if not covers(left, c):
			break
		left = left.sub_floor0(c)
		bought += 1
	return bought


## Index of the "Recommended" row or -1 (Q58, impl): among Type D rows not maxed with at most
## NEAR_MILESTONE levels to the next milestone the cheapest next level; else the cheapest affordable row;
## else none. Ties go to the first row.
static func recommended(rows: Array[FoundryRowView]) -> int:
	var best: int = -1
	for i: int in rows.size():
		var r: FoundryRowView = rows[i]
		var near: bool = r.kind == "D" and not r.maxed and r.levels_to_milestone <= NEAR_MILESTONE
		if near and (best < 0 or r.cost.lt(rows[best].cost)):
			best = i
	if best >= 0:
		return best
	for i: int in rows.size():
		var r: FoundryRowView = rows[i]
		if r.affordable and not r.maxed and (best < 0 or r.cost.lt(rows[best].cost)):
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
