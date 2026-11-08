class_name TestNumberRoll
extends GdUnitTestSuite
## NumberRoll (V1-16): 0.25 s ease-out, no overshoot; the 10 Hz label limiter of HudModel.


func test_reaches_target_within_duration() -> void:
	var r := NumberRoll.new()
	r.set_target(0.0, 0.0)
	r.set_target(1000.0, 1.0)
	assert_float(r.value_at(1.0)).is_equal(0.0)
	assert_float(r.value_at(1.0 + NumberRoll.DURATION_S)).is_equal(1000.0)
	assert_bool(r.is_done(1.0 + NumberRoll.DURATION_S)).is_true()
	assert_bool(r.is_done(1.1)).is_false()


func test_never_overshoots_up_or_down() -> void:
	var up := NumberRoll.new()
	up.set_target(10.0, 0.0)
	up.set_target(500.0, 0.0)
	var prev: float = 10.0
	for k: int in 40:
		var v: float = up.value_at(float(k) * 0.01)
		assert_float(v).is_between(10.0, 500.0)
		assert_float(v).is_greater_equal(prev)
		prev = v
	var down := NumberRoll.new()
	down.set_target(500.0, 0.0)
	down.set_target(10.0, 0.0)
	for k: int in 40:
		assert_float(down.value_at(float(k) * 0.01)).is_between(10.0, 500.0)


func test_retarget_restarts_from_displayed_value() -> void:
	var r := NumberRoll.new()
	r.set_target(0.0, 0.0)
	r.set_target(100.0, 0.0)
	var mid: float = r.value_at(0.1)
	r.set_target(200.0, 0.1)
	assert_float(r.value_at(0.1)).is_equal_approx(mid, 0.001)
	assert_float(r.value_at(0.35)).is_equal(200.0)


func test_first_value_and_instant_jump() -> void:
	var r := NumberRoll.new()
	r.set_target(42.0, 5.0)
	assert_float(r.value_at(5.0)).is_equal(42.0)
	r.set_target(900.0, 6.0, true)
	assert_float(r.value_at(6.0)).is_equal(900.0)


func test_ease_out_is_monotonic_and_bounded() -> void:
	var prev: float = 0.0
	for k: int in 21:
		var e: float = NumberRoll.ease_out(float(k) / 20.0)
		assert_float(e).is_between(0.0, 1.0)
		assert_float(e).is_greater_equal(prev)
		prev = e
	assert_float(NumberRoll.ease_out(1.5)).is_equal(1.0)


func test_label_limiter_allows_at_most_ten_updates_per_second() -> void:
	var m := HudModel.new()
	var allowed: int = 0
	for k: int in 120:  # two seconds at 60 fps
		if m.due(float(k) / 60.0):
			allowed += 1
	assert_int(allowed).is_less_equal(21)
	assert_int(allowed).is_greater_equal(19)
