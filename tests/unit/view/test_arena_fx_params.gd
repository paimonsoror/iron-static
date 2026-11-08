class_name TestArenaFxParams
extends GdUnitTestSuite
## V1-08: uniform mapping of the arena shaders (density fade, low-HP bands, tier toggles, phases, optic ring).


func test_density_fade_curve() -> void:
	assert_float(ArenaFxParams.density_fade(0)).is_equal(1.0)
	assert_float(ArenaFxParams.density_fade(100)).is_equal(1.0)
	assert_float(ArenaFxParams.density_fade(150)).is_equal_approx(0.5, 0.0001)
	assert_float(ArenaFxParams.density_fade(200)).is_equal(0.0)
	assert_float(ArenaFxParams.density_fade(900)).is_equal(0.0)


func test_low_hp_bands_and_static_fallback() -> void:
	assert_float(ArenaFxParams.low_hp(0, true)).is_equal(0.0)
	assert_float(ArenaFxParams.low_hp(1, true)).is_equal(0.0)
	assert_float(ArenaFxParams.low_hp(2, true)).is_equal(0.08)
	assert_float(ArenaFxParams.low_hp(3, true)).is_equal(0.45)
	assert_float(ArenaFxParams.low_hp(3, false)).is_equal(0.3)
	assert_float(ArenaFxParams.low_hp(2, false)).is_equal(0.08)


func test_tier_toggles_and_reduce_motion() -> void:
	var s := VisualSettings.new()
	assert_bool(ArenaFxParams.sweep_enabled(s)).is_true()
	assert_bool(ArenaFxParams.range_pulse_enabled(s)).is_true()
	assert_bool(ArenaFxParams.pulse_allowed(s)).is_true()
	s.set_tier(VisualQuality.Tier.MID)
	assert_bool(ArenaFxParams.sweep_enabled(s)).is_true()
	assert_bool(ArenaFxParams.range_pulse_enabled(s)).is_false()
	assert_float(s.effective_scanlines()).is_equal(0.0)
	s.set_tier(VisualQuality.Tier.LOW)
	assert_bool(ArenaFxParams.sweep_enabled(s)).is_false()
	assert_bool(ArenaFxParams.pulse_allowed(s)).is_false()
	s.set_tier(VisualQuality.Tier.HIGH)
	s.reduce_motion = true
	assert_bool(ArenaFxParams.sweep_enabled(s)).is_false()
	assert_bool(ArenaFxParams.range_pulse_enabled(s)).is_false()
	assert_bool(ArenaFxParams.pulse_allowed(s)).is_false()


func test_phases_wrap() -> void:
	assert_float(ArenaFxParams.sweep_phase(0.0)).is_equal(0.0)
	assert_float(ArenaFxParams.sweep_phase(2.0)).is_equal_approx(0.25, 0.0001)
	assert_float(ArenaFxParams.sweep_phase(8.0)).is_equal_approx(0.0, 0.0001)
	assert_float(ArenaFxParams.pulse_phase(1.0)).is_equal_approx(0.25, 0.0001)
	assert_float(ArenaFxParams.pulse_phase(6.0)).is_equal_approx(0.5, 0.0001)


func test_optic_and_art_scale() -> void:
	assert_float(ArenaFxParams.optic_px(0.0, 33.75)).is_equal(0.0)
	assert_float(ArenaFxParams.optic_px(24.0, 33.75)).is_equal_approx(24.0 * 33.75, 0.001)
	assert_float(ArenaFxParams.optic_px(10.0, 33.75)).is_equal_approx(ViewMath.map_dist(10.0, 33.75), 0.001)
	assert_float(ArenaFxParams.art_scale(33.75)).is_equal_approx(1.0, 0.0001)


func test_background_sets_uniforms_from_state() -> void:
	var parent := Node2D.new()
	var bg := ArenaBackground.new()
	parent.add_child(bg)
	add_child(parent)
	auto_free(parent)
	await get_tree().process_frame
	var vis := VisualSettings.new()
	bg.setup_visual(vis)
	bg.setup(33.75, 52.0, Rect2(-540.0, -537.6, 1080.0, 1075.2))
	bg.set_optic_range(24.0)
	bg.apply_state(2.0, 3, 150)
	var fx_rect: ColorRect = bg.get_child(0)
	var fx: ShaderMaterial = fx_rect.material
	var ov_rect: ColorRect = parent.get_child(parent.get_child_count() - 1)
	var ov: ShaderMaterial = ov_rect.material
	assert_float(fx.get_shader_parameter("sweep_phase")).is_equal_approx(0.25, 0.0001)
	assert_float(fx.get_shader_parameter("density")).is_equal_approx(0.5, 0.0001)
	assert_float(fx.get_shader_parameter("optic_range_px")).is_equal_approx(810.0, 0.01)
	assert_float(ov.get_shader_parameter("low_hp")).is_equal(0.45)
	assert_float(ov.get_shader_parameter("scan_alpha")).is_equal_approx(0.06, 0.0001)
	vis.reduce_motion = true
	bg.apply_state(2.0, 3, 0)
	assert_float(fx.get_shader_parameter("sweep_enabled")).is_equal(0.0)
	assert_float(ov.get_shader_parameter("scan_alpha")).is_equal(0.0)
	assert_float(ov.get_shader_parameter("low_hp")).is_equal(0.3)
