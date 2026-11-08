class_name TestCinderRig
extends GdUnitTestSuite


func _rig_at(band: int) -> CinderRig:
	var rig := CinderRig.new()
	rig.update(band, -PI * 0.5, 10.0)
	return rig


func test_first_update_snaps_without_transition() -> void:
	var rig: CinderRig = _rig_at(2)
	assert_bool(rig.animating()).is_false()
	assert_int(rig.band).is_equal(2)


func test_going_down_detaches_newly_gone_wedges() -> void:
	var rig: CinderRig = _rig_at(0)
	rig.update(2, -PI * 0.5, 10.1)
	for k: int in CinderWedges.BAND2_GONE:
		assert_int(rig.kind_of(k)).is_equal(CinderRig.KIND_DOWN)
	# wedge 1 stays intact in band 2? no: band 2 charres the rest, so it also changes (crossfade)
	assert_int(rig.kind_of(1)).is_equal(CinderRig.KIND_DOWN)
	rig.update(2, -PI * 0.5, 10.1 + CinderAnim.DETACH_S + 0.01)
	assert_bool(rig.animating()).is_false()


func test_going_up_reforms_one_per_step() -> void:
	var rig: CinderRig = _rig_at(3)
	rig.update(0, -PI * 0.5, 10.1)
	for k: int in 12:
		assert_int(rig.kind_of(k)).is_equal(CinderRig.KIND_UP)
	rig.update(0, -PI * 0.5, 10.1 + 0.7)
	assert_bool(rig.animating()).is_true()
	rig.update(0, -PI * 0.5, 10.1 + CinderAnim.reform_total() + 0.01)
	assert_bool(rig.animating()).is_false()


func test_no_animation_snaps() -> void:
	var rig: CinderRig = _rig_at(0)
	rig.animate = false
	rig.update(3, -PI * 0.5, 10.1)
	assert_bool(rig.animating()).is_false()
	assert_int(rig.states[0]).is_equal(CinderWedges.GONE)


func test_reduce_motion_kills_shiver_and_pulse() -> void:
	var rig: CinderRig = _rig_at(0)
	rig.reduce_motion = true
	rig.notify_hit()
	assert_vector(rig.shiver()).is_equal(Vector2.ZERO)
	rig.reduce_motion = false
	assert_bool(rig.shiver() != Vector2.ZERO).is_true()


func test_emitter_follows_aim_with_smoothing() -> void:
	var rig: CinderRig = _rig_at(0)
	rig.scale_f = 1.0
	# aim jumps 90 degrees: after 0.2 s of 60 fps updates the active node is on the aim
	var t: float = 10.0
	for i: int in 12:
		t += 1.0 / 60.0
		rig.update(0, 0.0, t)
	var dir: Vector2 = rig.emitter_position().normalized()
	assert_float(dir.angle_to(Vector2.RIGHT)).is_equal_approx(0.0, 0.05)
