class_name ClockSource
extends RefCounted
## Interface for wall time (the only way time enters the meta layer). Implementations: `SystemClock`
## (src/core, device time plus a server offset set by the backend in M7) and `FakeClock` (tests).


## Absolute UTC in unix seconds.
func now_utc() -> int:
	return 0


## Monotonic milliseconds since an arbitrary start (not wall time; use for durations).
func monotonic_ms() -> int:
	return 0


## True only when `now_utc` is anchored to a server time (offline claims in M6 require it).
func is_trusted() -> bool:
	return false
