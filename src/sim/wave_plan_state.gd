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
##
## Carry-over (GDD 02 section 6: spawns are never dropped): `begin(wave, true)` keeps the entries still
## unspawned from the previous wave, in arrival order, at the front of the new plan with spawn_tick 0 (due
## immediately, still subject to the alive caps). `carried` is how many such entries lead the plan. Bound:
## at most capacity / 2 entries are carried (the oldest win); the rest are lost and counted in
## `dropped_carry`. If the planner runs out of capacity, the slots it could not place are added to
## `dropped_slots`. Both counters are hashed; with the default tuning (caps 160 / 8, capacity 208) neither
## should ever be non-zero in a normal run.

var wave: int = 0
var built: bool = false
var count: int = 0
var cursor: int = 0
## Number of carried-over entries at the front of the plan (0 unless begin(wave, true) kept some).
var carried: int = 0
var dropped_carry: int = 0
var dropped_slots: int = 0
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


## Starts a new wave: empties the plan and marks it unbuilt. With `carry`, unspawned entries of the
## previous plan survive (see header); the planner appends the new wave's entries after them.
func begin(new_wave: int, carry: bool = false) -> void:
	wave = new_wave
	built = false
	var kept: int = 0
	if carry:
		var limit: int = capacity() >> 1
		for i: int in range(cursor, count):
			if spawned[i] != 0:
				continue
			if kept >= limit:
				dropped_carry += 1
				continue
			type_index[kept] = type_index[i]
			angle_idx[kept] = angle_idx[i]
			spawn_tick[kept] = 0
			spawned[kept] = 0
			kept += 1
	carried = kept
	count = kept
	cursor = 0
