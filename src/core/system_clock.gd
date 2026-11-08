class_name SystemClock
extends ClockSource
## Device wall time plus an optional server offset. `is_trusted()` stays false until the backend (M7)
## calls `set_server_time`; even then device time is only as honest as the last sync, so M6 offline
## claims decide for themselves how much to trust it.

## Seconds added to the device clock (0 until a server time is known).
var server_offset_s: int = 0


func now_utc() -> int:
	return int(Time.get_unix_time_from_system()) + server_offset_s


func monotonic_ms() -> int:
	return Time.get_ticks_msec()


## Always false in M3 (no backend). M7 will flip this when a server time has been received.
func is_trusted() -> bool:
	return false


## Called by the backend with the server's UTC (unix seconds); stores the offset to the device clock.
func set_server_time(utc: int) -> void:
	server_offset_s = utc - int(Time.get_unix_time_from_system())
