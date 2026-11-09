class_name TestBeamLook
extends GdUnitTestSuite
## VT-2: tier looks of the laser beam (docs/design/12 section 4.1, 8).


func _world() -> SimWorld:
	return SimWorld.new(SimConfigLoader.load_default(1))


func _row(world: SimWorld) -> int:
	for i: int in world.config.upgrades.size():
		if world.config.upgrades[i].id == "laser_output":
			return i
	return -1


func test_mk1_look_equals_the_old_constants() -> void:
	var look: BeamLook = BeamLook.for_level(0)
	assert_int(look.tier).is_equal(1)
	assert_bool(look.is_plain()).is_true()
	assert_float(look.muzzle).is_equal(1.0)
	for crit: bool in [false, true]:
		for mul: float in [1.0, 0.88, 1.12 * 0.85]:
			assert_vector(BeamMath.widths_for(look, crit, mul)).is_equal(BeamMath.widths(crit, mul))
	assert_object(BeamMath.glow_color(look.whiten)).is_equal(Palette.LASER_GLOW)
	assert_object(BeamMath.core_color_for(false, look.whiten)).is_equal(Palette.LASER_CORE)
	assert_object(BeamMath.core_color_for(true, look.whiten)).is_equal(Color.WHITE)
	assert_vector(BeamMath.widths_for(BeamLook.new(), false)).is_equal(Vector3(36.0, 8.0, 3.0))


func test_tiers_grow_with_the_level() -> void:
	var levels: Array[int] = [0, 5, 12, 25]
	var prev: BeamLook = null
	for n: int in 4:
		var look: BeamLook = BeamLook.for_level(levels[n])
		assert_int(look.tier).is_equal(n + 1)
		if prev != null:
			assert_float(look.glow_px).is_greater(prev.glow_px)
			assert_float(look.core_px).is_greater(prev.core_px)
			assert_float(look.hot_px).is_greater(prev.hot_px)
			assert_float(look.whiten).is_greater_equal(prev.whiten)
			assert_float(look.flare_px).is_greater(prev.flare_px)
		prev = look
	assert_int(BeamLook.for_level(24).tier).is_equal(3)
	var mk4: BeamLook = BeamLook.for_level(25)
	assert_float(mk4.rim).is_greater(0.0)
	assert_int(mk4.ripple).is_equal(6)
	assert_float(mk4.ring_px).is_greater(0.0)


func test_mk2_is_thicker_than_the_style_frame() -> void:
	var mk2: BeamLook = BeamLook.for_level(5)
	assert_float(mk2.glow_px).is_greater(54.0)
	assert_float(mk2.core_px).is_greater(13.0)
	assert_float(mk2.ring_px).is_equal(0.0)


func test_renderer_look_changes_only_when_the_tier_changes() -> void:
	var world: SimWorld = _world()
	var row: int = _row(world)
	assert_int(row).is_greater_equal(0)
	var beams: BeamRenderer = auto_free(BeamRenderer.new())
	beams.bind(world)
	assert_int(beams.look.tier).is_equal(1)
	var first: BeamLook = beams.look
	world.run_levels[row] = 4
	beams.update(world, 1.0, 20.0, Vector2.ZERO)
	assert_object(beams.look).is_same(first)
	world.run_levels[row] = 5
	beams.update(world, 1.1, 20.0, Vector2.ZERO)
	assert_int(beams.look.tier).is_equal(2)
	var mk2: BeamLook = beams.look
	world.run_levels[row] = 9
	beams.update(world, 1.2, 20.0, Vector2.ZERO)
	assert_object(beams.look).is_same(mk2)
	world.run_levels[row] = 30
	beams.update(world, 1.3, 20.0, Vector2.ZERO)
	assert_int(beams.look.tier).is_equal(4)
	beams.bind(world)
	assert_int(beams.look.tier).is_equal(4)
	world.run_levels[row] = 0
	beams.update(world, 1.4, 20.0, Vector2.ZERO)
	assert_int(beams.look.tier).is_equal(1)


func test_quality_ladder_and_reduce_motion() -> void:
	var beams: BeamRenderer = auto_free(BeamRenderer.new())
	beams.look = BeamLook.for_level(25)
	assert_array(Array(beams.active_parts())).is_equal(["flare", "ring", "rim", "ripple"])
	var vs := VisualSettings.new()
	beams.visual = vs
	assert_array(Array(beams.active_parts())).is_equal(["flare", "ring", "rim", "ripple"])
	vs.set_tier(VisualQuality.Tier.MID)
	assert_array(Array(beams.active_parts())).is_equal(["flare", "rim"])
	vs.set_tier(VisualQuality.Tier.LOW)
	assert_array(Array(beams.active_parts())).is_empty()
	vs.set_tier(VisualQuality.Tier.HIGH)
	vs.reduce_motion = true
	assert_array(Array(beams.active_parts())).is_equal(["flare", "ring", "rim"])
	beams.look = BeamLook.for_level(0)
	assert_array(Array(beams.active_parts())).is_empty()
