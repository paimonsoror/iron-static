class_name WavePlanState
extends RefCounted
## The current wave's spawn plan and pending-spawn queue (owned by SimWorld as `world.plan`, written by
## SpawnSystem M1-08; layout declared here in M1-07 so the system needs no SimWorld edits).
##
## Entries 0..count-1 are sorted by `spawn_tick` (ticks within the wave, 0-539). `spawned[i]` is 1 once
## entry i has been spawned. `cursor` is the first entry that may still be unspawned: every entry below it
## is spawned; entries above it may already be spawned if a throttled entry was skipped over.
## SimWorld.step() calls `begin(wave)` at wave_tick 0 (built = false); SpawnSystem builds the plan on the
## first tick it sees `built == false` and sets `built = true`.

var wave: int = 0
var built: bool = false
var count: int = 0
var cursor: int = 0
## Enemy type index per entry.
var type_index: PackedInt32Array
## Wave tick at which the entry becomes due.
var spawn_tick: PackedInt32Array
## Start angle as an index into SinCosTable (0..4095).
var angle_idx: PackedInt32Array
var spawned: PackedByteArray


func _init(slots: int) -> void:
	type_index = PackedInt32Array()
	spawn_tick = PackedInt32Array()
	angle_idx = PackedInt32Array()
	spawned = PackedByteArray()
	if (
		type_index.resize(slots) != OK
		or spawn_tick.resize(slots) != OK
		or angle_idx.resize(slots) != OK
		or spawned.resize(slots) != OK
	):
		push_error("WavePlanState: resize failed")


func capacity() -> int:
	return type_index.size()


## Starts a new wave: empties the plan and marks it unbuilt.
func begin(new_wave: int) -> void:
	wave = new_wave
	built = false
	count = 0
	cursor = 0
