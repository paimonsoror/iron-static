class_name UnlockRules
extends RefCounted
## Which run upgrade rows are visible from the best sector-1 wave (GDD 02 section 7, 08 section 1.3).


## 1 where `gate_best_wave <= best_wave_s1`, else 0; index-aligned with `defs`.
static func visible(defs: Array[RunUpgradeDef], best_wave_s1: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	var n: int = out.resize(defs.size())
	if n != OK:
		return out
	for i: int in defs.size():
		out[i] = 1 if defs[i].gate_best_wave <= best_wave_s1 else 0
	return out


## (row index, gate wave) of the locked row with the lowest gate (first in table order on ties), or (-1, 0).
static func next_unlock(defs: Array[RunUpgradeDef], best_wave_s1: int) -> Vector2i:
	var best: Vector2i = Vector2i(-1, 0)
	for i: int in defs.size():
		var gate: int = defs[i].gate_best_wave
		if gate > best_wave_s1 and (best.x < 0 or gate < best.y):
			best = Vector2i(i, gate)
	return best
