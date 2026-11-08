class_name NumberRoll
extends RefCounted
## Pure interpolation for counters (art bible 7.5): the displayed number eases out to a new target over DURATION_S
## (display only). Never overshoots; a new target restarts from the currently displayed value. The caller owns the
## clock (`now_s`) and the 10 Hz label limit (`HudModel.due`), so this holds no node and allocates nothing.

const DURATION_S: float = 0.25

var _from: float = 0.0
var _to: float = 0.0
var _t0: float = 0.0
var _started: bool = false


## Sets a new target. `instant` (first value, reduce motion) jumps. An unchanged target is a no-op.
func set_target(target: float, now_s: float, instant: bool = false) -> void:
	if not _started or instant:
		_started = true
		_from = target
		_to = target
		_t0 = now_s
		return
	if target == _to:
		return
	_from = value_at(now_s)
	_to = target
	_t0 = now_s


## Displayed value at `now_s` (between the start value and the target, ease-out cubic).
func value_at(now_s: float) -> float:
	if now_s - _t0 >= DURATION_S:
		return _to
	return lerpf(_from, _to, ease_out((now_s - _t0) / DURATION_S))


func is_done(now_s: float) -> bool:
	return now_s - _t0 >= DURATION_S or _from == _to


func target_value() -> float:
	return _to


## 1 - (1 - t)^3 on t in 0..1 (clamped), monotonic from 0 to 1.
static func ease_out(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	var u: float = 1.0 - c
	return 1.0 - u * u * u
