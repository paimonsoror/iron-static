class_name TestBeamAfterglow
extends GdUnitTestSuite
## R1-06: beam afterglow and floor scorch math, caps by quality tier, reduce motion and the slow-rate core.

const START: Vector2 = Vector2(0.0, 0.0)
const END: Vector2 = Vector2(200.0, -100.0)


func _settings(tier: VisualQuality.Tier, calm: bool) -> VisualSettings:
	var vs := VisualSettings.new()
	vs.set_tier(tier)
	vs.reduce_motion = calm
	return vs


func test_core_fade_stretches_under_two_shots_a_second() -> void:
	assert_float(BeamAfterglow.core_fade_s(1)).is_equal(0.12)
	assert_float(BeamAfterglow.core_fade_s(2)).is_equal(BeamMath.FADE_S)
	assert_float(BeamAfterglow.core_fade_s(9)).is_equal(0.08)
	assert_float(BeamMath.fade_alpha(0.10)).is_equal(0.0)  # default 80 ms core is gone
	assert_float(BeamMath.fade_alpha(0.10, 0.12)).is_greater(0.0)
	assert_float(BeamMath.fade_alpha(0.12, 0.12)).is_equal(0.0)


func test_afterglow_decays_over_about_300_ms() -> void:
	assert_float(BeamAfterglow.glow_alpha(0.0, false)).is_equal(0.0)  # ramps in from the live beam
	var early: float = BeamAfterglow.glow_alpha(0.05, false)
	var mid: float = BeamAfterglow.glow_alpha(0.15, false)
	var late: float = BeamAfterglow.glow_alpha(0.28, false)
	assert_float(early).is_greater(mid)
	assert_float(mid).is_greater(late)
	assert_float(late).is_greater(0.0)
	assert_float(BeamAfterglow.glow_alpha(0.30, false)).is_equal(0.0)
	assert_float(BeamAfterglow.glow_alpha(-0.1, false)).is_equal(0.0)
	assert_float(early).is_less_equal(BeamAfterglow.GLOW_PEAK)


func test_scorch_fades_linearly_over_one_second() -> void:
	assert_float(BeamAfterglow.scorch_alpha(0.0, false)).is_equal_approx(BeamAfterglow.SCORCH_PEAK, 0.0001)
	assert_float(BeamAfterglow.scorch_alpha(0.5, false)).is_equal_approx(BeamAfterglow.SCORCH_PEAK * 0.5, 0.0001)
	assert_float(BeamAfterglow.scorch_alpha(1.0, false)).is_equal(0.0)


func test_reduce_motion_shortens_but_keeps_both() -> void:
	assert_float(BeamAfterglow.glow_s(true)).is_less(BeamAfterglow.glow_s(false))
	assert_float(BeamAfterglow.glow_s(true)).is_greater(0.0)
	assert_float(BeamAfterglow.glow_alpha(0.10, true)).is_greater(0.0)
	assert_float(BeamAfterglow.glow_alpha(0.16, true)).is_equal(0.0)
	assert_float(BeamAfterglow.scorch_alpha(0.3, true)).is_greater(0.0)
	assert_float(BeamAfterglow.scorch_alpha(0.55, true)).is_equal(0.0)


func test_caps_scale_with_the_quality_tier() -> void:
	assert_int(BeamAfterglow.glow_cap(VisualQuality.Tier.HIGH)).is_greater(
		BeamAfterglow.glow_cap(VisualQuality.Tier.MID)
	)
	assert_int(BeamAfterglow.glow_cap(VisualQuality.Tier.MID)).is_greater(
		BeamAfterglow.glow_cap(VisualQuality.Tier.LOW)
	)
	assert_int(BeamAfterglow.glow_cap(VisualQuality.Tier.LOW)).is_greater(0)
	assert_int(BeamAfterglow.scorch_cap(VisualQuality.Tier.HIGH)).is_less_equal(BeamScorch.RING)
	assert_int(BeamAfterglow.scorch_cap(VisualQuality.Tier.MID)).is_greater(
		BeamAfterglow.scorch_cap(VisualQuality.Tier.LOW)
	)


func test_renderer_afterglow_count_is_capped_per_tier() -> void:
	for t: VisualQuality.Tier in [VisualQuality.Tier.HIGH, VisualQuality.Tier.MID, VisualQuality.Tier.LOW]:
		var r: BeamRenderer = auto_free(BeamRenderer.new())
		r.visual = _settings(t, false)
		for k: int in 20:  # 100 Hz at 30 px apart: no merge, the 16-slot pool is full of live afterglows
			r.shoot(START, END + Vector2(float(k) * 30.0, 0.0), 10.0 + float(k) * 0.01)
		var n: int = r.afterglow_count(10.24)
		assert_int(n).is_equal(mini(BeamAfterglow.glow_cap(t), BeamRenderer.MAX_BEAMS))
		assert_int(r.live_count(10.24)).is_less_equal(BeamRenderer.MAX_BEAMS)


func test_renderer_slow_shot_keeps_its_core_for_120_ms_fast_shots_for_80() -> void:
	var slow: BeamRenderer = auto_free(BeamRenderer.new())
	slow.shoot(START, END, 100.0)
	assert_int(slow.live_count(100.10)).is_equal(1)
	assert_int(slow.live_count(100.13)).is_equal(0)
	assert_int(slow.afterglow_count(100.13)).is_equal(1)  # the afterglow outlives the core
	assert_int(slow.afterglow_count(100.35)).is_equal(0)
	var fast: BeamRenderer = auto_free(BeamRenderer.new())
	for k: int in 3:
		fast.shoot(START, END + Vector2(0.0, float(k) * 40.0), 200.0 + float(k) * 0.3)
	assert_int(fast.live_count(200.65)).is_equal(1)  # only the last shot is within its 80 ms core


func test_scorch_lines_are_capped_by_tier_and_expire() -> void:
	for t: VisualQuality.Tier in [VisualQuality.Tier.HIGH, VisualQuality.Tier.MID, VisualQuality.Tier.LOW]:
		var s: BeamScorch = auto_free(BeamScorch.new())
		s.visual = _settings(t, false)
		for k: int in 20:
			s.add(START, END, 5.0 + float(k) * 0.01)
		assert_int(s.live_count(5.3)).is_equal(BeamAfterglow.scorch_cap(t))
		assert_int(s.live_count(7.0)).is_equal(0)


func test_renderer_feeds_scorch_except_for_merged_beams() -> void:
	var r: BeamRenderer = auto_free(BeamRenderer.new())
	var s: BeamScorch = auto_free(BeamScorch.new())
	r.scorch = s
	for k: int in 10:  # 20 shots a second at the same end: shots 9 and 10 merge into the sustained beam
		r.shoot(START, END, 50.0 + float(k) * 0.05)
	assert_int(s.added).is_equal(8)


func test_mk_tiers_keep_distinct_afterglow_widths() -> void:
	var widths: Array[float] = []
	for level: int in [0, 5, 12, 25]:
		var look: BeamLook = BeamLook.for_level(level)
		widths.append(BeamMath.widths_for(look, false).x * BeamAfterglow.GLOW_WIDTH_MUL)
	for i: int in 3:
		assert_float(widths[i + 1]).is_greater_equal(widths[i])
	assert_float(widths[3]).is_greater(widths[0])
