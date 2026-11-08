class_name EnemyFxState
extends RefCounted
## Per-enemy-slot view state for the textured renderer: hit flash (1 -> 0 over 90 ms) and spawn age. Fed by
## `ENEMY_HIT` / `ENEMY_SPAWNED` events through a private EventCursor; both arrays are indexed by the enemy
## store slot and reset when a slot is spawned (slots are reused). Pure observer: never touches the sim.

## Age stored for enemies that were already alive when the view bound (no spawn-in).
const SPAWNED_AGE_S: float = 99.0

var flash: PackedFloat32Array = PackedFloat32Array()
var spawn_age: PackedFloat32Array = PackedFloat32Array()
## Test hook: number of array resizes (must stay constant after the first bind).
var resize_count: int = 0
var _events := EventCursor.new()


## Sizes the arrays to `capacity` (no-op when already that size) and skips events pushed so far.
func bind(events: SimEvents, capacity: int) -> void:
	if flash.size() != capacity:
		var ok: bool = flash.resize(capacity) == OK and spawn_age.resize(capacity) == OK
		if not ok:
			push_error("EnemyFxState: resize failed")
		resize_count += 1
	flash.fill(0.0)
	spawn_age.fill(SPAWNED_AGE_S)
	_events.sync_to(events)


## Events lost because the view fell behind the ring.
func events_lost_total() -> int:
	return _events.lost_total


## Applies the new events: a hit sets the flash to 1, a spawn restarts the spawn-in and clears the flash.
func consume(events: SimEvents) -> void:
	var cap: int = flash.size()
	while _events.poll(events) > 0:
		for i: int in _events.count:
			var kind: int = _events.kind_at(i)
			var idx: int = _events.a_at(i)
			if idx < 0 or idx >= cap:
				continue
			if kind == SimEventKind.ENEMY_HIT:
				flash[idx] = 1.0
			elif kind == SimEventKind.ENEMY_SPAWNED:
				flash[idx] = 0.0
				spawn_age[idx] = 0.0


## Advances the timers of slots 0..count-1 by `dt` seconds (wall time).
func advance(dt: float, count: int) -> void:
	var n: int = mini(count, flash.size())
	for i: int in n:
		var f: float = flash[i]
		if f > 0.0:
			flash[i] = EnemyInstanceData.decay_flash(f, dt)
		var a: float = spawn_age[i]
		if a < SPAWNED_AGE_S:
			spawn_age[i] = minf(a + dt, SPAWNED_AGE_S)


func flash_at(index: int) -> float:
	return flash[index] if index >= 0 and index < flash.size() else 0.0


func spawn_at(index: int) -> float:
	if index < 0 or index >= spawn_age.size():
		return 1.0
	return EnemyInstanceData.spawn_factor(spawn_age[index])
