class_name RepeatBuyModel
extends RefCounted
## Hold-to-buy timing (V1-25; GDD 07 section 2.2). Pure: hold time in seconds -> purchase steps. The first repeat
## comes at FIRST_S, then the interval eases linearly from SLOW_S to FAST_S over EASE_S. After TEN_AT_S each step
## asks for 10 levels, after HUNDRED_AT_S for 100 (the only counts `command_buy` accepts besides 1 and Max).
## (impl) All thresholds are tuning values; the sim buys a partial amount when the full count is unaffordable.

const FIRST_S: float = 0.35
const SLOW_S: float = 0.25
const FAST_S: float = 0.05
const EASE_S: float = 2.0
const TEN_AT_S: float = 3.0
const HUNDRED_AT_S: float = 6.0
const MAX_EVENTS_PER_POLL: int = 16

var _next_s: float = FIRST_S


## Interval to the step after the one at `hold_s`.
static func interval_at(hold_s: float) -> float:
	var f: float = clampf((hold_s - FIRST_S) / EASE_S, 0.0, 1.0)
	return lerpf(SLOW_S, FAST_S, f)


## Levels per step at `hold_s`: 1, 10 or 100.
static func batch_at(hold_s: float) -> int:
	if hold_s >= HUNDRED_AT_S:
		return 100
	if hold_s >= TEN_AT_S:
		return 10
	return 1


func reset() -> void:
	_next_s = FIRST_S


## Steps due up to `hold_s` since the last call: x = number of steps, y = levels per step (of the last one).
func poll(hold_s: float) -> Vector2i:
	var events: int = 0
	var batch: int = 1
	while hold_s >= _next_s and events < MAX_EVENTS_PER_POLL:
		batch = batch_at(_next_s)
		events += 1
		_next_s += interval_at(_next_s)
	if events == MAX_EVENTS_PER_POLL and hold_s >= _next_s:
		_next_s = hold_s + interval_at(hold_s)  # hitch: drop the backlog
	return Vector2i(events, batch)
