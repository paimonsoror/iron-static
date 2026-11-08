class_name StatResolver
extends RefCounted
## Type D / Type C stat formulas (GDD 02 section 5, 05 sections 1.2-1.3). Pure static; no allocation beyond
## the returned StatBlock.

const MILESTONE_STEP: int = 25  # gold ring distance (08 section 1.3)


## `run_levels[i]` / `foundry_levels[i]` / `foundry_f[i]` belong to `defs[i]`; missing entries (empty arrays)
## count as 0. Type D: `base * run_factor(min(L, l_cap), p) * foundry_mult(F, f) * mult + add`.
## Type C: `clamp(base + step * min(L, l_cap) + f_inc * min(F, F_cap) + add, 0, hard_cap) * mult`, with
## `f_inc = step` and `F_cap = max(1, floor(l_cap / 2))` (GDD 05 section 1.3). `mults` null = neutral.
static func resolve(
	defs: Array[RunUpgradeDef],
	run_levels: PackedInt32Array,
	foundry_levels: PackedInt32Array,
	foundry_f: PackedFloat64Array,
	mults: ExternalMults
) -> StatBlock:
	var m: ExternalMults = mults if mults != null else ExternalMults.new()
	var s: StatBlock = StatBlock.new()
	for i: int in defs.size():
		var def: RunUpgradeDef = defs[i]
		var lvl: int = run_levels[i] if i < run_levels.size() else 0
		var fl: int = foundry_levels[i] if i < foundry_levels.size() else 0
		var ff: float = foundry_f[i] if i < foundry_f.size() else 0.0
		s.set_stat(def.id, _value(def, lvl, fl, ff, m.mult_for(def.id), m.add_for(def.id)))
	return s


## Distance to the next multiple of 25 (a level that is already a multiple gives 25).
static func levels_to_next_milestone(level: int) -> int:
	return MILESTONE_STEP - (maxi(level, 0) % MILESTONE_STEP)


static func foundry_cap(def: RunUpgradeDef) -> int:
	return maxi(1, floori(float(def.l_cap) / 2.0))


static func _value(def: RunUpgradeDef, level: int, f_level: int, f: float, mult: float, add: float) -> float:
	var l: int = clampi(level, 0, def.l_cap)
	if def.kind == "D":
		return def.base * Curves.run_factor(l, def.step) * Curves.foundry_mult(maxi(f_level, 0), f) * mult + add
	var fl: int = clampi(f_level, 0, foundry_cap(def))
	var v: float = def.base + def.step * float(l) + def.step * float(fl) + add
	var hi: float = def.hard_cap if def.has_hard_cap else INF
	return clampf(v, 0.0, hi) * mult
