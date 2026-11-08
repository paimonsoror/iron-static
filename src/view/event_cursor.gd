class_name EventCursor
extends RefCounted
## Reads SimEvents from a private cursor in fixed-size batches without allocating.
## Usage: `while cursor.poll(world.events) > 0: for i in cursor.count: ... cursor.kind_at(i)`.
## Counts events lost when the view falls more than SimEvents.CAPACITY behind.

const BATCH: int = 64

## Events in `buf` after the latest poll().
var count: int = 0
## Total events skipped because the ring wrapped past this reader.
var lost_total: int = 0
## Number of polls that detected a loss (the "warning counter").
var lost_warnings: int = 0
var cursor: int = 0
var buf: PackedInt32Array


func _init() -> void:
	if buf.resize(BATCH * SimEvents.FIELDS) != OK:
		push_error("EventCursor: resize failed")


## Drains up to BATCH unseen events into the buffer; returns how many (0 = caught up).
func poll(events: SimEvents) -> int:
	var before: int = cursor
	cursor = events.drain(cursor, buf)
	var lost: int = events.last_drain_lost
	if lost > 0:
		lost_total += lost
		lost_warnings += 1
	count = cursor - before - lost
	return count


## Skips everything pushed so far (use when binding to a world mid-run).
func sync_to(events: SimEvents) -> void:
	cursor = events.total_pushed
	count = 0


func tick_at(i: int) -> int:
	return buf[i * SimEvents.FIELDS]


func kind_at(i: int) -> int:
	return buf[i * SimEvents.FIELDS + 1]


func a_at(i: int) -> int:
	return buf[i * SimEvents.FIELDS + 2]


func b_at(i: int) -> int:
	return buf[i * SimEvents.FIELDS + 3]
