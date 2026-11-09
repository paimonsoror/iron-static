class_name PatchState
extends RefCounted
## Patches picked this deployment (GDD 02 section 10; M4-14): pick count per patch index (the row order of
## data/patches.csv, `SimConfig.patches`). Empty (all zero) means no patch effect and no hash contribution.

var picks: PackedInt32Array = PackedInt32Array()
var total_picks: int = 0


func _init(patch_count: int = 0) -> void:
	if picks.resize(patch_count) != OK:
		push_error("PatchState: resize failed")
	picks.fill(0)


## Picks of patch `index` (0 for an unknown index).
func qty(index: int) -> int:
	if index < 0 or index >= picks.size():
		return 0
	return picks[index]


## Records one more pick of `index` (the caller checked `max_picks`). Returns false for an unknown index.
func add(index: int) -> bool:
	if index < 0 or index >= picks.size():
		return false
	picks[index] += 1
	total_picks += 1
	return true


## Sets every count at once (tests, snapshot restore); recomputes `total_picks`.
func set_picks(values: PackedInt32Array) -> void:
	picks = values.duplicate()
	total_picks = 0
	for v: int in picks:
		total_picks += v
