class_name StatResolver
extends RefCounted
## Type D / Type C stat formulas (GDD 02 section 5, 05 sections 1.2-1.3). Pure static; no allocation beyond
## the returned StatBlock.


## `run_levels[i]` / `foundry_levels[i]` / `foundry_f[i]` belong to `defs[i]`; missing entries (empty arrays)
## count as 0. Type D: `base * run_factor(min(L, l_cap), p) * foundry_mult(F, f) * mult + add`.
## Type C: `clamp(base + step * min(L, l_cap) + f_inc * min(F, F_cap) + add, 0, hard_cap) * mult`, with
## `f_inc = step` and `F_cap = max(1, floor(l_cap / 2))` (GDD 05 section 1.3). `mults` null = neutral.
## `tuning` supplies the milestone step and multiplier (R1-02; null = `Curves` fallback).
static func resolve(
	defs: Array[RunUpgradeDef],
	run_levels: PackedInt32Array,
	foundry_levels: PackedInt32Array,
	foundry_f: PackedFloat64Array,
	mults: ExternalMults,
	tuning: SimTuning = null
) -> StatBlock:
	var m: ExternalMults = mults if mults != null else ExternalMults.new()
	var s: StatBlock = StatBlock.new()
	for i: int in defs.size():
		var def: RunUpgradeDef = defs[i]
		var lvl: int = run_levels[i] if i < run_levels.size() else 0
		var fl: int = foundry_levels[i] if i < foundry_levels.size() else 0
		var ff: float = foundry_f[i] if i < foundry_f.size() else 0.0
		s.set_stat(def.id, _value(def, lvl, fl, ff, m.mult_for(def.id), m.add_for(def.id), tuning))
	s.data_yield = m.data_yield_mult
	s.enemy_damage = m.enemy_damage_mult
	return s


## Stat value of one row at `level`; Foundry level/factor and external mult/add default to none (UI previews).
static func value_at(
	def: RunUpgradeDef,
	level: int,
	f_level: int = 0,
	f: float = 0.0,
	mult: float = 1.0,
	add: float = 0.0,
	tuning: SimTuning = null
) -> float:
	return _value(def, level, f_level, f, mult, add, tuning)


## Distance to the next run milestone level (a level that is already a multiple gives a full step). The step is
## `run_milestone_step` (08 section 1.3 gold ring distance; 25 with the shipped data).
static func levels_to_next_milestone(level: int, tuning: SimTuning = null) -> int:
	var step: int = Curves.run_step(tuning)
	return step - (maxi(level, 0) % step)


static func foundry_cap(def: RunUpgradeDef) -> int:
	return maxi(1, floori(float(def.l_cap) / 2.0))


static func _value(
	def: RunUpgradeDef, level: int, f_level: int, f: float, mult: float, add: float, tuning: SimTuning
) -> float:
	var l: int = clampi(level, 0, def.l_cap)
	if def.kind == "D":
		return (
			def.base * Curves.run_factor(l, def.step, tuning) * Curves.foundry_mult(maxi(f_level, 0), f, tuning) * mult
			+ add
		)
	var fl: int = clampi(f_level, 0, foundry_cap(def))
	var v: float = def.base + def.step * float(l) + def.step * float(fl) + add
	var hi: float = def.hard_cap if def.has_hard_cap else INF
	return clampf(v, 0.0, hi) * mult
