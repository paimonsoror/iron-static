class_name TestSystemClock
extends GdUnitTestSuite
## SystemClock (M3-03): device time, server offset hook, never trusted in M3.


func test_now_close_to_system_time() -> void:
	var c: SystemClock = SystemClock.new()
	var diff: int = absi(c.now_utc() - int(Time.get_unix_time_from_system()))
	assert_bool(diff <= 5).is_true()


func test_not_trusted() -> void:
	assert_bool(SystemClock.new().is_trusted()).is_false()


func test_set_server_time_sets_offset() -> void:
	var c: SystemClock = SystemClock.new()
	var target: int = int(Time.get_unix_time_from_system()) + 3600
	c.set_server_time(target)
	assert_bool(absi(c.now_utc() - target) <= 2).is_true()
	assert_bool(absi(c.server_offset_s - 3600) <= 2).is_true()
	assert_bool(c.is_trusted()).is_false()


func test_monotonic_does_not_go_back() -> void:
	var c: SystemClock = SystemClock.new()
	var a: int = c.monotonic_ms()
	assert_bool(c.monotonic_ms() >= a).is_true()
