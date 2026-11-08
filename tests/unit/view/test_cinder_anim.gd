class_name TestCinderAnim
extends GdUnitTestSuite


func test_detach_ends_transparent_at_0_6_s() -> void:
	assert_float(CinderAnim.detach_alpha(CinderAnim.DETACH_S)).is_equal(0.0)
	assert_float(CinderAnim.detach_alpha(0.0)).is_equal(1.0)
	assert_float(CinderAnim.detach_scale(0.0)).is_equal(1.0)
	assert_float(CinderAnim.detach_scale(CinderAnim.DETACH_S)).is_equal_approx(1.15, 0.0001)


func test_detach_distance_in_range_for_every_wedge() -> void:
	for k: int in CinderWedges.WEDGE_COUNT:
		var end: float = CinderAnim.detach_offset(k, CinderAnim.DETACH_S)
		assert_bool(end >= 60.0 and end <= 110.0).is_true()
		assert_float(CinderAnim.detach_offset(k, 0.0)).is_equal(0.0)
		assert_float(CinderAnim.detach_offset(k, 5.0)).is_equal(end)


func test_reform_schedule_is_12_steps_of_0_125_s() -> void:
	assert_int(CinderAnim.REFORM_STEPS).is_equal(12)
	for k: int in 12:
		assert_float(CinderAnim.reform_start(k)).is_equal_approx(0.125 * float(k), 0.00001)
	assert_float(CinderAnim.reform_total()).is_equal_approx(1.5, 0.00001)
	assert_float(CinderAnim.reform_scale(0.0)).is_equal_approx(0.7, 0.00001)
	assert_float(CinderAnim.reform_scale(1.0)).is_equal(1.0)
	assert_float(CinderAnim.reform_flash(0.0)).is_equal(1.0)
	assert_float(CinderAnim.reform_flash(0.06)).is_equal(0.0)


func test_pulse_bounded_and_rates() -> void:
	for band: int in 4:
		var lo: float = 9.0
		var hi: float = -9.0
		for i: int in 2000:
			var v: float = CinderAnim.pulse(band, float(i) * 0.003)
			lo = minf(lo, v)
			hi = maxf(hi, v)
		assert_bool(lo >= 0.0 and hi <= 1.0).is_true()
	# 1 Hz: same value one second later; band 2 repeats after 1/1.3 s; band 3 after 1/1.2 s
	assert_float(CinderAnim.pulse(0, 0.2)).is_equal_approx(CinderAnim.pulse(0, 1.2), 0.0001)
	assert_float(CinderAnim.pulse(2, 0.1)).is_equal_approx(CinderAnim.pulse(2, 0.1 + 1.0 / 1.3), 0.0001)
	assert_float(CinderAnim.pulse(3, 0.1)).is_equal_approx(CinderAnim.pulse(3, 0.1 + 1.0 / 1.2), 0.0001)


func test_heartbeat_has_two_peaks() -> void:
	var first: float = CinderAnim.pulse(3, 0.08 / 1.2)
	var second: float = CinderAnim.pulse(
		3, (HeartbeatModel.FIRST_PHASE + HeartbeatModel.GAP_S * HeartbeatModel.HZ) / 1.2
	)
	var between: float = CinderAnim.pulse(3, 0.19 / 1.2)
	assert_float(first).is_equal_approx(1.0, 0.001)
	assert_float(second).is_equal_approx(0.7, 0.001)
	assert_bool(between < 0.2).is_true()


func test_aim_step_never_exceeds_540_deg_per_s() -> void:
	var cur: float = 0.0
	var dt: float = 1.0 / 60.0
	var cap: float = deg_to_rad(540.0) * dt
	for i: int in 120:
		var nxt: float = CinderAnim.aim_step(cur, PI - 0.01 if i < 60 else -2.0, dt)
		assert_bool(absf(nxt - cur) <= cap + 0.000001).is_true()
		cur = nxt


func test_aim_step_takes_shortest_way_and_converges() -> void:
	# from +170 to -170 degrees the short way is across 180
	var cur: float = deg_to_rad(170.0)
	var nxt: float = CinderAnim.aim_step(cur, deg_to_rad(-170.0), 0.016)
	assert_bool(nxt > cur).is_true()
	var a: float = 0.0
	for i: int in 300:
		a = CinderAnim.aim_step(a, 1.0, 0.016)
	assert_float(a).is_equal_approx(1.0, 0.001)


func test_shiver_bounded_and_zero_after_100_ms() -> void:
	for s: int in 20:
		for i: int in 100:
			var t: float = float(i) * 0.001
			var o: Vector2 = CinderAnim.shiver_offset(t, s)
			assert_bool(absf(o.x) <= 2.0 and absf(o.y) <= 2.0).is_true()
		assert_vector(CinderAnim.shiver_offset(0.1, s)).is_equal(Vector2.ZERO)
		assert_vector(CinderAnim.shiver_offset(0.5, s)).is_equal(Vector2.ZERO)
		assert_vector(CinderAnim.shiver_offset(-1.0, s)).is_equal(Vector2.ZERO)


func test_boosts_decay() -> void:
	assert_float(CinderAnim.hit_boost(0.0)).is_equal_approx(0.6, 0.0001)
	assert_float(CinderAnim.hit_boost(0.1)).is_equal(0.0)
	assert_float(CinderAnim.shot_boost(0.0)).is_equal(1.0)
	assert_float(CinderAnim.shot_boost(1.0)).is_equal(0.0)


func test_ember_flicker_steady_in_band_1_and_bounded_in_2() -> void:
	assert_float(CinderAnim.ember_flicker(1, 0.3)).is_equal(CinderAnim.ember_flicker(1, 0.9))
	for i: int in 200:
		var v: float = CinderAnim.ember_flicker(2, float(i) * 0.01)
		assert_bool(v >= 0.7 and v <= 1.0).is_true()
