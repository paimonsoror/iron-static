class_name TestVisualSettingsFps
extends GdUnitTestSuite
## Frame cap (V1-24): default 60, options 30/60, applied through Engine.max_fps, and never a sim-speed change.

var _saved_cap: int = 0


func before_test() -> void:
	_saved_cap = Engine.max_fps


func after_test() -> void:
	Engine.max_fps = _saved_cap


func test_default_and_options() -> void:
	var s := VisualSettings.new()
	assert_int(s.fps_cap).is_equal(60)
	assert_array(VisualSettings.FPS_CAPS).is_equal([30, 60])


func test_snap_picks_nearest_option() -> void:
	assert_int(VisualSettings.snap_fps_cap(30)).is_equal(30)
	assert_int(VisualSettings.snap_fps_cap(60)).is_equal(60)
	assert_int(VisualSettings.snap_fps_cap(10)).is_equal(30)
	assert_int(VisualSettings.snap_fps_cap(120)).is_equal(60)
	assert_int(VisualSettings.snap_fps_cap(45)).is_equal(60)


func test_apply_sets_engine_max_fps() -> void:
	var s := VisualSettings.new()
	s.set_fps_cap(30)
	assert_int(Engine.max_fps).is_equal(30)
	s.set_fps_cap(100)
	assert_int(Engine.max_fps).is_equal(60)
	s.fps_cap = 0
	s.apply_fps_cap()
	assert_int(Engine.max_fps).is_equal(0)


func _ticks_after(frame_s: float, seconds: float) -> Array:
	var c := RunController.new()
	c.last_run_path = "user://runs/test_fps_cap.json"
	var w: SimWorld = c.start_run(5)
	c.driver.budget_usec = 1_000_000_000
	var frames: int = roundi(seconds / frame_s)
	for i: int in frames:
		@warning_ignore("return_value_discarded")
		c.update(frame_s)
	return [w.tick, w.state_hash()]


func test_cap_changes_frames_not_sim_speed() -> void:
	# 10 s of wall time at a 30 fps and a 60 fps frame rate: the same tick count (+-1 for the leftover accumulator).
	var at30: Array = _ticks_after(1.0 / 30.0, 10.0)
	var at60: Array = _ticks_after(1.0 / 60.0, 10.0)
	var t30: int = at30[0]
	var t60: int = at60[0]
	assert_int(absi(t30 - t60)).is_less_equal(1)
	assert_int(t30).is_greater_equal(299)
	# Same tick count gives the same state: the cap has no way to alter outcomes.
	if t30 == t60:
		assert_str(at30[1]).is_equal(at60[1])
