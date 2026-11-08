class_name TestResultsAnim
extends GdUnitTestSuite


func test_reveal_schedule_is_0_3_plus_0_12_k() -> void:
	for k: int in 8:
		assert_float(ResultsAnim.reveal_time(k)).is_equal_approx(0.3 + 0.12 * float(k), 0.0001)


func test_tally_reaches_exact_final_at_0_6_s() -> void:
	for final_value: float in [7.0, 12345.0, 1.5e12, 98765432.0]:
		assert_float(ResultsAnim.tally(final_value, 1.0 + 0.6, 1.0, false)).is_equal(final_value)
		assert_float(ResultsAnim.tally(final_value, 1.0, 1.0, false)).is_equal(0.0)
		var mid: float = ResultsAnim.tally(final_value, 1.3, 1.0, false)
		assert_float(mid).is_greater(0.0)
		assert_float(mid).is_less(final_value)


func test_tally_is_monotonic_and_never_overshoots() -> void:
	var prev: float = -1.0
	for i: int in 41:
		var v: float = ResultsAnim.tally(100.0, 0.02 * float(i), 0.0, false)
		assert_float(v).is_greater_equal(prev)
		assert_float(v).is_less_equal(100.0)
		prev = v


func test_reduce_motion_is_instant() -> void:
	assert_float(ResultsAnim.tally(50.0, 0.0, 0.5, true)).is_equal(50.0)
	assert_float(ResultsAnim.line_alpha(5, 0.0, true)).is_equal(1.0)
	assert_float(ResultsAnim.slide_offset(0.0, true)).is_equal(0.0)
	assert_float(ResultsAnim.header_jitter(0.0, true)).is_equal(0.0)
	assert_float(ResultsAnim.pulse(0.4, true)).is_equal(0.0)
	assert_float(ResultsAnim.total_s(7, true)).is_equal(0.0)


func test_buttons_enabled_no_later_than_m2() -> void:
	# M2 had no entry delay: the button was tappable immediately.
	assert_float(ResultsAnim.BUTTONS_ENABLED_S).is_less_equal(0.0)


func test_pulse_stays_in_range_and_header_settles() -> void:
	for i: int in 40:
		var p: float = ResultsAnim.pulse(0.1 * float(i), false)
		assert_float(p).is_between(0.0, ResultsAnim.PULSE_AMOUNT + 0.0001)
	assert_float(ResultsAnim.header_jitter(ResultsAnim.HEADER_S, false)).is_equal(0.0)
	assert_float(ResultsAnim.slide_offset(ResultsAnim.HEADER_S, false)).is_equal_approx(0.0, 0.0001)


func test_accent_colors_per_enemy() -> void:
	assert_object(ResultsAnim.accent_for("skitter")).is_equal(Color("#FF2D4B"))
	assert_object(ResultsAnim.accent_for("dart")).is_equal(Color("#FF4FD8"))
	assert_object(ResultsAnim.accent_for("walker")).is_equal(Color("#FF7A1A"))
	assert_object(ResultsAnim.accent_for("lancer")).is_equal(Color("#A35CFF"))
	assert_object(ResultsAnim.accent_for("boss_hulk")).is_equal(Color("#FF1F3D"))
