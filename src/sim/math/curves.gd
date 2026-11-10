class_name Curves
extends RefCounted
## GDD formulas as pure static functions (03 sections 2-4, 02 sections 5-6, 05 section 1.2).

## Milestones (02 section 5: run_factor x1.5 every 25 levels; 05 section 1.2: foundry_mult x1.75 every 25 levels) are
## data since R1-02 (C-07): `run_milestone_step/mult` and `foundry_milestone_step/mult` in data/sim_constants.csv,
## read from a `SimTuning`. The FALLBACK_* values are the documented fallback for a caller that has no tuning at hand
## (UI previews, unit tests); `test_curves.gd` asserts they equal the data rows, so they cannot drift silently.
## Every production path (sim, Foundry, Intel, rows) passes its real tuning.
const FALLBACK_RUN_STEP: int = 25
const FALLBACK_RUN_MULT: float = 1.5
const FALLBACK_FOUNDRY_STEP: int = 25
const FALLBACK_FOUNDRY_MULT: float = 1.75


## Piecewise exponential growth (03 section 4.2). r1..r3 are growth factors per level;
## e1/e2 are the phase end levels (200, 600). Level 1 gives 1.0.
static func g_growth(l: int, r1: float, r2: float, r3: float, e1: int, e2: int) -> float:
	var k1: float = log(r1)
	var k2: float = log(r2)
	var k3: float = log(r3)
	if l <= e1:
		return exp(k1 * float(l - 1))
	if l <= e2:
		return exp(k1 * float(e1 - 1) + k2 * float(l - e1))
	return exp(k1 * float(e1 - 1) + k2 * float(e2 - e1) + k3 * float(l - e2))


## Spawn slots per wave: min(cap, floor(base + coef * w^exp)).
static func slots_for_wave(w: int, base: float, coef: float, power: float, cap: int) -> int:
	return mini(cap, floori(base + coef * pow(float(w), power)))


## Base scrap per kill: max(1, round(k * g_hp^exp)).
static func scrap_per_kill_base(g_hp: float, k: float, power: float) -> int:
	return maxi(1, roundi(k * pow(g_hp, power)))


## Base data per kill: data_base * (1 + coef * level) * reward.
static func data_per_kill_base(data_base: float, level: int, coef: float, reward: float) -> float:
	return data_base * (1.0 + coef * float(level)) * reward


## Sector reward multiplier R(s) = growth^(s-1).
static func sector_reward(s: int, growth: float) -> float:
	return pow(growth, float(s - 1))


## Levels between run milestones (`run_milestone_step`); `t` null = the documented fallback.
static func run_step(t: SimTuning = null) -> int:
	return maxi(1, t.run_milestone_step if t != null else FALLBACK_RUN_STEP)


## Multiplier gained at each run milestone (`run_milestone_mult`).
static func run_mult(t: SimTuning = null) -> float:
	return t.run_milestone_mult if t != null else FALLBACK_RUN_MULT


## Levels between Foundry milestones (`foundry_milestone_step`).
static func foundry_step(t: SimTuning = null) -> int:
	return maxi(1, t.foundry_milestone_step if t != null else FALLBACK_FOUNDRY_STEP)


## Multiplier gained at each Foundry milestone (`foundry_milestone_mult`).
static func foundry_milestone_mult(t: SimTuning = null) -> float:
	return t.foundry_milestone_mult if t != null else FALLBACK_FOUNDRY_MULT


## Run upgrade multiplier: (1 + p*L) * run_mult^floor(L/run_step) (1.5 every 25 levels with the shipped data).
static func run_factor(level: int, p: float, t: SimTuning = null) -> float:
	var steps: int = floori(float(level) / float(run_step(t)))
	return (1.0 + p * float(level)) * pow(run_mult(t), float(steps))


## Foundry multiplier: (1 + f*F) * foundry_milestone_mult^floor(F/foundry_step) (1.75 every 25 with the shipped data).
static func foundry_mult(f_level: int, f: float, t: SimTuning = null) -> float:
	var steps: int = floori(float(f_level) / float(foundry_step(t)))
	return (1.0 + f * float(f_level)) * pow(foundry_milestone_mult(t), float(steps))


## Cost of buying the upgrade at `level` (next level): ceil(c0 * g^level).
static func upgrade_cost(c0: float, g: float, level: int) -> float:
	return ceil(c0 * pow(g, float(level)))


## Total cost of `count` sequential purchases starting at `from_level` (no discount).
static func sum_cost(c0: float, g: float, from_level: int, count: int) -> float:
	var total: float = 0.0
	for i: int in count:
		total += upgrade_cost(c0, g, from_level + i)
	return total
