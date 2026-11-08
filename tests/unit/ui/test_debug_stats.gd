class_name TestDebugStats
extends GdUnitTestSuite


func test_zero_samples_are_zero() -> void:
	var s := DebugStats.new(10)
	assert_int(s.count()).is_equal(0)
	assert_float(s.average()).is_equal(0.0)
	assert_float(s.minimum()).is_equal(0.0)
	assert_float(s.period_average()).is_equal(0.0)
	assert_float(s.period_min()).is_equal(0.0)


func test_average_and_min_before_window_fills() -> void:
	var s := DebugStats.new(10)
	s.add(10.0)
	s.add(20.0)
	s.add(30.0)
	assert_int(s.count()).is_equal(3)
	assert_float(s.average()).is_equal_approx(20.0, 0.0001)
	assert_float(s.minimum()).is_equal(10.0)


func test_window_rolls_over_oldest_samples() -> void:
	var s := DebugStats.new(3)
	for v: float in [1.0, 2.0, 3.0, 10.0, 20.0]:
		s.add(v)
	# window now holds 3, 10, 20
	assert_int(s.count()).is_equal(3)
	assert_float(s.average()).is_equal_approx(11.0, 0.0001)
	assert_float(s.minimum()).is_equal(3.0)


func test_min_forgets_old_minimum() -> void:
	var s := DebugStats.new(2)
	s.add(1.0)
	s.add(5.0)
	s.add(6.0)
	assert_float(s.minimum()).is_equal(5.0)


func test_period_covers_all_samples_until_reset() -> void:
	var s := DebugStats.new(2)
	for v: float in [4.0, 8.0, 12.0, 2.0]:
		s.add(v)
	assert_int(s.period_count()).is_equal(4)
	assert_float(s.period_average()).is_equal_approx(6.5, 0.0001)
	assert_float(s.period_min()).is_equal(2.0)
	s.reset_period()
	assert_int(s.period_count()).is_equal(0)
	assert_float(s.period_min()).is_equal(0.0)
	s.add(9.0)
	assert_float(s.period_min()).is_equal(9.0)
	assert_int(s.count()).is_equal(2)


func test_clear_and_window_floor() -> void:
	var s := DebugStats.new(0)
	s.add(3.0)
	s.add(4.0)
	assert_int(s.count()).is_equal(1)
	assert_float(s.average()).is_equal(4.0)
	s.clear()
	assert_int(s.count()).is_equal(0)
	assert_float(s.average()).is_equal(0.0)


func test_perf_line_format() -> void:
	var line: String = DebugOverlay.perf_line(59.96, 41.2, 0.4567, 160)
	assert_str(line).is_equal("[PERF] fps=60.0 min=41.2 tick_ms=0.46 enemies=160")
