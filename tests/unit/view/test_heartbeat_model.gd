class_name TestHeartbeatModel
extends GdUnitTestSuite
## V1-15: double-beat curve, haze intensity curve, ease, reduce-motion/tier and override routing.


func _samples(n: int) -> Array[float]:
	var out: Array[float] = []
	var per: float = HeartbeatModel.period_s()
	for i: int in n:
		out.append(HeartbeatModel.value(per * float(i) / float(n)))
	return out


func test_bounds_and_period() -> void:
	for i: int in 3000:
		var v: float = HeartbeatModel.value(float(i) * 0.0013)
		assert_bool(v >= 0.0 and v <= 1.0).is_true()
	assert_float(HeartbeatModel.period_s()).is_equal_approx(0.8333, 0.001)
	assert_float(HeartbeatModel.value(0.3)).is_equal_approx(
		HeartbeatModel.value(0.3 + HeartbeatModel.period_s()), 0.0001
	)


func test_two_maxima_second_at_70_percent_and_0_18_s_apart() -> void:
	var n: int = 2000
	var s: Array[float] = _samples(n)
	var peaks: Array[int] = []
	for i: int in n:
		var prev: float = s[(i + n - 1) % n]
		var next: float = s[(i + 1) % n]
		if s[i] > 0.05 and s[i] > prev and s[i] >= next:
			peaks.append(i)
	assert_int(peaks.size()).is_equal(2)
	assert_float(s[peaks[0]]).is_equal_approx(1.0, 0.01)
	assert_float(s[peaks[1]] / s[peaks[0]]).is_equal_approx(0.7, 0.05)
	var gap_s: float = float(peaks[1] - peaks[0]) / float(n) * HeartbeatModel.period_s()
	assert_float(gap_s).is_equal_approx(0.18, 0.01)


func test_intensity_curve_band3_between_025_and_045() -> void:
	var lo: float = 9.0
	var hi: float = -9.0
	for i: int in 1000:
		var v: float = ArenaFxParams.low_hp_intensity(
			ArenaFxParams.low_hp_base(3, true),
			ArenaFxParams.low_hp_swing(3, true),
			HeartbeatModel.value(float(i) * 0.002)
		)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	assert_float(lo).is_equal_approx(0.25, 0.001)
	assert_float(hi).is_equal_approx(0.45, 0.001)


func test_bands_and_static_modes() -> void:
	assert_float(ArenaFxParams.low_hp_base(0, true)).is_equal(0.0)
	assert_float(ArenaFxParams.low_hp_base(1, true)).is_equal(0.0)
	assert_float(ArenaFxParams.low_hp_base(2, true)).is_equal(0.08)
	assert_float(ArenaFxParams.low_hp_swing(2, true)).is_equal(0.0)
	# reduce motion / LOW tier: static 0.3 at band 3, no swing, beat value irrelevant.
	assert_float(ArenaFxParams.low_hp_base(3, false)).is_equal(0.3)
	assert_float(ArenaFxParams.low_hp_swing(3, false)).is_equal(0.0)
	var s := VisualSettings.new()
	s.reduce_motion = true
	assert_bool(ArenaFxParams.pulse_allowed(s)).is_false()


func test_ease_reaches_95_percent_in_450_ms_without_overshoot() -> void:
	var v: float = 0.0
	var t: float = 0.0
	while t < 0.45 - 0.0001:
		v = ArenaFxParams.ease_step(v, 0.25, 1.0 / 60.0)
		t += 1.0 / 60.0
		assert_bool(v <= 0.25).is_true()
	assert_bool(v >= 0.95 * 0.25 - 0.002).is_true()
	# not a step: the first frame moves only a little
	assert_bool(ArenaFxParams.ease_step(0.0, 1.0, 1.0 / 60.0) < 0.2).is_true()
	assert_float(ArenaFxParams.ease_step(0.3, 0.0, 0.0)).is_equal(0.3)


func test_cinder_core_uses_the_same_curve() -> void:
	for i: int in 200:
		var t: float = float(i) * 0.011
		assert_float(CinderAnim.pulse(3, t)).is_equal(HeartbeatModel.value(t))


func test_override_routing() -> void:
	assert_int(BattleView.displayed_band(1, -1)).is_equal(1)
	assert_int(BattleView.displayed_band(1, 3)).is_equal(3)
	assert_int(BattleView.displayed_band(3, 0)).is_equal(0)
