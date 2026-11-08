class_name DebugStats
extends RefCounted
## Pure rolling statistics for the debug overlay (M1-24). Two views of the same samples:
## a rolling window of the last `window` samples (average, minimum) and a "period" aggregate
## (average, minimum, count since the last reset) used for the 10 s [PERF] report.
## No allocation after construction: the window is a preallocated ring buffer.

var _window: int
var _ring: PackedFloat64Array
var _next: int = 0
var _count: int = 0
var _sum: float = 0.0
var _period_sum: float = 0.0
var _period_min: float = 0.0
var _period_count: int = 0


func _init(window: int = 60) -> void:
	_window = maxi(window, 1)
	_ring = PackedFloat64Array()
	if _ring.resize(_window) != OK:
		push_error("DebugStats: resize failed")


## Adds one sample to the rolling window and to the period aggregate.
func add(value: float) -> void:
	if _count == _window:
		_sum -= _ring[_next]
	else:
		_count += 1
	_ring[_next] = value
	_sum += value
	_next = (_next + 1) % _window
	if _period_count == 0 or value < _period_min:
		_period_min = value
	_period_sum += value
	_period_count += 1


## Samples currently in the window (at most `window`).
func count() -> int:
	return _count


## Rolling average, 0.0 with no samples.
func average() -> float:
	if _count == 0:
		return 0.0
	return _sum / float(_count)


## Rolling minimum over the window, 0.0 with no samples.
func minimum() -> float:
	if _count == 0:
		return 0.0
	var m: float = _ring[0]
	for i: int in _count:
		m = minf(m, _ring[i])
	return m


func period_count() -> int:
	return _period_count


func period_average() -> float:
	if _period_count == 0:
		return 0.0
	return _period_sum / float(_period_count)


func period_min() -> float:
	return _period_min if _period_count > 0 else 0.0


## Starts a new period (the rolling window is untouched).
func reset_period() -> void:
	_period_sum = 0.0
	_period_min = 0.0
	_period_count = 0


## Empties everything.
func clear() -> void:
	_next = 0
	_count = 0
	_sum = 0.0
	reset_period()
