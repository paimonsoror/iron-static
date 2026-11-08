class_name TestVisualQuality
extends GdUnitTestSuite
## V1-03: tier presets (art bible 9.3), arg parsing with fallback, density glow ramp, settings helpers.


func test_high_is_everything_on() -> void:
	var q: VisualQuality = VisualQuality.high()
	assert_int(q.tier).is_equal(VisualQuality.Tier.HIGH)
	assert_int(q.particle_cap).is_equal(400)
	assert_bool(q.scanlines).is_true()
	assert_bool(q.motes).is_true()
	assert_bool(q.glow_sheets).is_true()
	assert_bool(q.sweep).is_true()
	assert_bool(q.range_pulse).is_true()
	assert_bool(q.impact_rings).is_true()
	assert_float(q.shake_max_px).is_equal(10.0)


func test_mid_matches_art_bible() -> void:
	var q: VisualQuality = VisualQuality.mid()
	assert_int(q.tier).is_equal(VisualQuality.Tier.MID)
	assert_int(q.particle_cap).is_equal(200)
	assert_bool(q.scanlines).is_false()
	assert_bool(q.motes).is_false()
	assert_bool(q.range_pulse).is_false()
	assert_bool(q.impact_rings).is_false()
	assert_float(q.shake_max_px).is_equal(5.0)
	assert_bool(q.glow_sheets).is_true()
	assert_bool(q.sweep).is_true()


func test_low_matches_art_bible() -> void:
	var q: VisualQuality = VisualQuality.low()
	assert_int(q.tier).is_equal(VisualQuality.Tier.LOW)
	assert_int(q.particle_cap).is_equal(80)
	assert_bool(q.glow_sheets).is_false()
	assert_bool(q.sweep).is_false()
	assert_bool(q.vignette_pulse).is_false()
	assert_bool(q.wedge_anim).is_false()
	assert_int(q.sparks_per_hit).is_equal(2)
	assert_bool(q.scanlines).is_false()


func test_for_tier_and_names() -> void:
	assert_int(VisualQuality.for_tier(VisualQuality.Tier.LOW).particle_cap).is_equal(80)
	assert_str(VisualQuality.mid().tier_name()).is_equal("mid")


func test_quality_arg_parses() -> void:
	assert_int(VisualQuality.tier_from_args(PackedStringArray(["--quality=low"]))).is_equal(VisualQuality.Tier.LOW)
	assert_int(VisualQuality.tier_from_args(PackedStringArray(["--debug-perf", "--quality=MID"]))).is_equal(
		VisualQuality.Tier.MID
	)


func test_missing_or_unknown_quality_falls_back_to_high() -> void:
	assert_int(VisualQuality.tier_from_args(PackedStringArray())).is_equal(VisualQuality.Tier.HIGH)
	assert_int(VisualQuality.parse_tier("ultra")).is_equal(VisualQuality.Tier.HIGH)
	assert_int(VisualQuality.parse_tier("")).is_equal(VisualQuality.Tier.HIGH)


func test_glow_ramp_follows_density() -> void:
	var q: VisualQuality = VisualQuality.high()
	assert_float(q.glow_strength(0)).is_equal(1.0)
	assert_float(q.glow_strength(40)).is_equal(1.0)
	assert_float(q.glow_strength(165)).is_equal_approx(0.45, 0.0001)
	assert_float(q.glow_strength(400)).is_equal_approx(0.45, 0.0001)
	assert_float(q.glow_strength(102)).is_equal_approx(0.725, 0.01)
	assert_float(VisualQuality.low().glow_strength(10)).is_equal(0.0)


func test_settings_defaults_and_args() -> void:
	var s: VisualSettings = VisualSettings.from_args(PackedStringArray())
	assert_int(s.quality.tier).is_equal(VisualQuality.Tier.HIGH)
	assert_int(s.screen_shake).is_equal(VisualSettings.Shake.LOW)
	assert_float(s.scanline_intensity).is_equal_approx(0.06, 0.0001)
	var t: VisualSettings = VisualSettings.from_args(PackedStringArray(["--quality=low", "--shake=normal"]))
	assert_int(t.quality.tier).is_equal(VisualQuality.Tier.LOW)
	assert_int(t.screen_shake).is_equal(VisualSettings.Shake.NORMAL)
	assert_int(VisualSettings.parse_shake("bogus")).is_equal(VisualSettings.Shake.LOW)


func test_effective_values_respect_tier_and_reduce_motion() -> void:
	var s := VisualSettings.new()
	assert_float(s.effective_shake_px()).is_equal(5.0)
	assert_float(s.effective_scanlines()).is_equal_approx(0.06, 0.0001)
	s.screen_shake = VisualSettings.Shake.NORMAL
	assert_float(s.effective_shake_px()).is_equal(10.0)
	s.set_tier(VisualQuality.Tier.MID)
	assert_float(s.effective_shake_px()).is_equal(5.0)
	assert_float(s.effective_scanlines()).is_equal(0.0)
	s.set_tier(VisualQuality.Tier.HIGH)
	s.reduce_motion = true
	assert_float(s.effective_shake_px()).is_equal(0.0)
	assert_float(s.effective_scanlines()).is_equal(0.0)


func test_set_tier_emits_signal() -> void:
	var s := VisualSettings.new()
	var seen: Array[int] = []
	s.quality_changed.connect(func(t: int) -> void: seen.append(t))
	s.set_tier(VisualQuality.Tier.LOW)
	assert_array(seen).is_equal([2])
	assert_int(s.quality.tier).is_equal(VisualQuality.Tier.LOW)
