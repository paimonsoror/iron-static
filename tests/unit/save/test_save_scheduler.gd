class_name TestSaveScheduler
extends GdUnitTestSuite
## SaveScheduler cadence with a fake dt (M3-12).

const FS: int = SaveScheduler.FLAG_SAVE
const FC: int = SaveScheduler.FLAG_CHECKPOINT


func _count(s: SaveScheduler, seconds: float, in_menu: bool, in_run: bool, paused: bool, flag: int) -> int:
	var n: int = 0
	var t: float = 0.0
	while t < seconds:
		if s.advance(0.1, in_menu, in_run, paused) & flag:
			n += 1
		t += 0.1
	return n


func test_burst_of_requests_inside_debounce_is_one_write() -> void:
	var s: SaveScheduler = SaveScheduler.new()
	var writes: int = 0
	for i: int in 10:
		s.request_save()
		if s.advance(0.15, false, false) & FS:
			writes += 1
	assert_int(writes).is_equal(0)  # 1.5 s so far
	writes += _count(s, 3.0, false, false, false, FS)
	assert_int(writes).is_equal(1)


func test_nothing_fires_when_idle_outside_a_menu() -> void:
	var s: SaveScheduler = SaveScheduler.new()
	assert_int(_count(s, 200.0, false, false, false, FS | FC)).is_equal(0)


func test_menu_autosaves_every_60_seconds() -> void:
	var s: SaveScheduler = SaveScheduler.new()
	assert_int(_count(s, 59.0, true, false, false, FS)).is_equal(0)
	assert_int(_count(s, 2.0, true, false, false, FS)).is_equal(1)
	assert_int(_count(s, 125.0, true, false, false, FS)).is_equal(2)


func test_leaving_the_menu_resets_the_menu_timer() -> void:
	var s: SaveScheduler = SaveScheduler.new()
	assert_int(_count(s, 50.0, true, false, false, FS)).is_equal(0)
	assert_int(_count(s, 1.0, false, false, false, FS)).is_equal(0)
	assert_int(_count(s, 50.0, true, false, false, FS)).is_equal(0)


func test_checkpoint_every_30_seconds_of_run_time_not_while_paused() -> void:
	var s: SaveScheduler = SaveScheduler.new()
	assert_int(_count(s, 29.0, false, true, false, FC)).is_equal(0)
	assert_int(_count(s, 2.0, false, true, false, FC)).is_equal(1)
	assert_int(_count(s, 300.0, false, true, true, FC)).is_equal(0)
	assert_int(_count(s, 61.0, false, true, false, FC)).is_equal(2)


func test_notify_saved_clears_pending() -> void:
	var s: SaveScheduler = SaveScheduler.new()
	s.request_save()
	assert_bool(s.is_pending()).is_true()
	s.notify_saved()
	assert_bool(s.is_pending()).is_false()
	assert_int(_count(s, 5.0, false, false, false, FS)).is_equal(0)
