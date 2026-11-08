class_name FakeClock
extends ClockSource
## Test clock: time moves only when the test says so.

var utc: int = 0
var mono_ms: int = 0
var trusted: bool = false


func _init(start_utc: int = 0) -> void:
	utc = start_utc


func advance(seconds: int) -> void:
	utc += seconds
	mono_ms += seconds * 1000


func now_utc() -> int:
	return utc


func monotonic_ms() -> int:
	return mono_ms


func is_trusted() -> bool:
	return trusted
