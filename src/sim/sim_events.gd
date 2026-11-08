class_name SimEvents
extends RefCounted
## Ring buffer of the last 1024 sim events for views and sounds (TECH_ARCHITECTURE 2.1). Four packed arrays,
## written by `push`, read by `drain` with a caller-owned cursor. Events are not part of `state_hash()`.
## The buffer never allocates after construction. A reader that falls more than CAPACITY events behind
## loses the oldest events (reported in `last_drain_lost`).

const CAPACITY: int = 1024
const FIELDS: int = 4  ## ints per event in a drain output: tick, kind, a, b

var tick_at: PackedInt32Array
var kind: PackedInt32Array
var a: PackedInt32Array
var b: PackedInt32Array
## Total events ever pushed; also the cursor value of a reader that is fully caught up.
var total_pushed: int = 0
## Tick stamped on pushed events; SimWorld.step() sets it at the start of every tick.
var tick: int = 0
## Events skipped by the most recent `drain` call because the ring had wrapped past the cursor.
var last_drain_lost: int = 0


func _init() -> void:
	tick_at = _make()
	kind = _make()
	a = _make()
	b = _make()


func push(event_kind: int, event_a: int, event_b: int) -> void:
	var i: int = total_pushed & (CAPACITY - 1)
	tick_at[i] = tick
	kind[i] = event_kind
	a[i] = event_a
	b[i] = event_b
	total_pushed += 1


## Copies unseen events (those with index >= cursor) into `out` as flat quadruples
## `(tick, kind, a, b)`, at most `out.size() / 4` events, and returns the new cursor. Start with cursor 0.
## `out` is caller-owned (no allocation here); pass a buffer of 4 * 64 or more.
func drain(cursor: int, out: PackedInt32Array) -> int:
	var oldest: int = maxi(0, total_pushed - CAPACITY)
	last_drain_lost = 0
	if cursor < oldest:
		last_drain_lost = oldest - cursor
		cursor = oldest
	var n: int = mini(total_pushed - cursor, out.size() >> 2)
	for k: int in n:
		var i: int = (cursor + k) & (CAPACITY - 1)
		var o: int = k * FIELDS
		out[o] = tick_at[i]
		out[o + 1] = kind[i]
		out[o + 2] = a[i]
		out[o + 3] = b[i]
	return cursor + n


static func _make() -> PackedInt32Array:
	var arr: PackedInt32Array = PackedInt32Array()
	if arr.resize(CAPACITY) != OK:
		push_error("SimEvents: resize failed")
	return arr
