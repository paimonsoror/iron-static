class_name CameraFit
extends RefCounted
## Smooth zoom of the auto-fit camera (V1-23). Holds the eased camera width; `step()` is called once per frame with
## the fit target (ViewMath.fit_width_m) and the wall clock. A new target starts a smoothstep ease from the current
## width over ViewMath.ZOOM_EASE_S; reduce motion snaps. Pure and allocation-free: same inputs, same widths.

var width_m: float = 0.0

var _from_m: float = 0.0
var _to_m: float = 0.0
var _t0_s: float = 0.0
var _started: bool = false


## Jumps to `target_m` (bind, viewport resize).
func snap(target_m: float) -> void:
	width_m = target_m
	_from_m = target_m
	_to_m = target_m
	_started = true


## True while a zoom is in progress.
func easing() -> bool:
	return _started and width_m != _to_m


## Advances to `now_s` (monotonic wall seconds) and returns the camera width in meters. The first call snaps.
func step(target_m: float, now_s: float, reduce_motion: bool) -> float:
	if not _started or reduce_motion:
		snap(target_m)
		return width_m
	if target_m != _to_m:
		_from_m = width_m
		_to_m = target_m
		_t0_s = now_s
	var k: float = clampf((now_s - _t0_s) / ViewMath.ZOOM_EASE_S, 0.0, 1.0)
	if k >= 1.0:
		width_m = _to_m
	else:
		width_m = lerpf(_from_m, _to_m, k * k * (3.0 - 2.0 * k))
	return width_m
