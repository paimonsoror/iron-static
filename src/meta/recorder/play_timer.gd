class_name PlayTimer
extends RefCounted
## Foreground play time through the injected `ClockSource` (monotonic ms). `sample` is called every frame the app
## runs; a gap longer than `MAX_GAP_MS` between two samples (a stall, or the app was suspended) counts only up to that
## cap, and `suspend` (app paused or lost focus) makes the next sample start fresh, so background time never counts.
## `take_seconds` hands out whole seconds and keeps the remainder.

const MAX_GAP_MS: int = 1000

var _last_ms: int = -1
var _acc_ms: int = 0


func sample(clock: ClockSource) -> void:
	var now: int = clock.monotonic_ms()
	if _last_ms >= 0:
		_acc_ms += clampi(now - _last_ms, 0, MAX_GAP_MS)
	_last_ms = now


## The app goes to the background: nothing counts until the next sample, which only re-anchors.
func suspend() -> void:
	_last_ms = -1


## Whole seconds counted since the last call (the sub-second remainder stays).
func take_seconds() -> int:
	var whole: int = floori(float(_acc_ms) / 1000.0)
	_acc_ms -= whole * 1000
	return whole
