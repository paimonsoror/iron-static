class_name TestBeamMath
extends GdUnitTestSuite


func _times_at_rate(rate: float, now_s: float) -> PackedFloat64Array:
	var t := PackedFloat64Array()
	var n: int = ceili(rate * 2.0)
	for k: int in n:
		t.append(now_s - float(k) / rate)
	return t


func test_fade_alpha_boundaries() -> void:
	assert_float(BeamMath.fade_alpha(-0.01)).is_equal(0.0)
	assert_float(BeamMath.fade_alpha(0.0)).is_equal(1.0)
	assert_float(BeamMath.fade_alpha(0.04)).is_equal_approx(0.5, 1e-6)
	assert_float(BeamMath.fade_alpha(0.08)).is_equal(0.0)
	assert_float(BeamRenderer.fade_alpha(0.02)).is_equal_approx(0.75, 1e-6)


func test_merged_alpha_pulses_between_floor_and_one_then_fades() -> void:
	assert_float(BeamMath.merged_alpha(0.0)).is_equal(1.0)
	assert_float(BeamMath.merged_alpha(BeamMath.FADE_S - 0.0001)).is_equal_approx(BeamMath.MERGED_FLOOR, 0.01)
	assert_float(BeamMath.merged_alpha(BeamMath.FADE_S * 1.5)).is_equal_approx(BeamMath.MERGED_FLOOR * 0.5, 1e-5)
	assert_float(BeamMath.merged_alpha(BeamMath.FADE_S * 2.0)).is_equal(0.0)


func test_crit_widths_are_one_and_a_half_times() -> void:
	var n: Vector3 = BeamMath.widths(false)
	var c: Vector3 = BeamMath.widths(true)
	assert_vector(n).is_equal(Vector3(36.0, 8.0, 3.0))
	assert_float(c.x).is_equal_approx(n.x * 1.5, 1e-5)
	assert_float(c.y).is_equal_approx(n.y * 1.5, 1e-5)
	assert_float(c.z).is_equal_approx(n.z * 1.5, 1e-5)


func test_crit_core_is_white() -> void:
	assert_object(BeamMath.core_color(true)).is_equal(Color.WHITE)
	assert_object(BeamMath.core_color(false)).is_equal(Palette.LASER_CORE)


func test_jitter_within_bounds_for_10000_samples() -> void:
	var lo: float = 10.0
	var hi: float = -10.0
	for i: int in 10000:
		var j: Vector2 = BeamMath.jitter(i)
		assert_bool(j.x >= 0.88 - 1e-6 and j.x <= 1.12 + 1e-6).is_true()
		assert_bool(absf(j.y) <= 2.0 + 1e-6).is_true()
		lo = minf(lo, j.x)
		hi = maxf(hi, j.x)
	assert_float(hi - lo).is_greater(0.2)
	assert_vector(BeamMath.jitter(77)).is_equal(BeamMath.jitter(77))


func test_merge_triggers_only_above_8_shots_per_second() -> void:
	var now_s: float = 5.0
	assert_bool(BeamMath.should_merge(BeamMath.shots_in_window(_times_at_rate(6.0, now_s), now_s))).is_false()
	assert_bool(BeamMath.should_merge(BeamMath.shots_in_window(_times_at_rate(8.0, now_s), now_s))).is_false()
	assert_bool(BeamMath.should_merge(BeamMath.shots_in_window(_times_at_rate(12.0, now_s), now_s))).is_true()


func test_renderer_merges_at_12_hz_and_not_at_6_hz() -> void:
	var slow := BeamRenderer.new()
	var fast := BeamRenderer.new()
	var end := Vector2(0.0, -300.0)
	for k: int in 12:
		slow.shoot(Vector2.ZERO, end, 10.0 + float(k) / 6.0)
		fast.shoot(Vector2.ZERO, end, 10.0 + float(k) / 12.0)
	# 6 Hz: each beam lives 80 ms of 167, one live at a time; the ring advanced 12 slots.
	assert_int(slow._next).is_equal(12)
	# 12 Hz: the first 8 shots add (rate not yet above 8 until the 9th), the rest merge into one beam.
	assert_int(fast._next).is_less(12)
	assert_int(fast._next).is_greater_equal(8)
	slow.free()
	fast.free()


func test_pool_never_exceeds_16() -> void:
	var r := BeamRenderer.new()
	for k: int in 100:
		# distinct ends so nothing merges, all within one fade window
		r.shoot(Vector2.ZERO, Vector2(float(k) * 20.0, -300.0), 1.0 + float(k) * 0.0001)
	assert_int(r.live_count(1.01)).is_less_equal(BeamRenderer.MAX_BEAMS)
	assert_int(r.live_count(1.01)).is_equal(BeamRenderer.MAX_BEAMS)
	assert_int(r.live_count(2.0)).is_equal(0)
	r.free()


func test_pool_slot_reuse_overwrites_oldest() -> void:
	var r := BeamRenderer.new()
	for k: int in 17:
		r.shoot(Vector2.ZERO, Vector2(float(k) * 50.0, -300.0), 0.0)
	assert_int(r._next).is_equal(1)
	assert_float(r._end[0].x).is_equal_approx(800.0, 3.0)
	r.free()


func test_geometry_length_angle_and_cap_placement() -> void:
	var la: Vector2 = BeamMath.length_angle(Vector2(10.0, 10.0), Vector2(10.0, -190.0))
	assert_float(la.x).is_equal_approx(200.0, 1e-4)
	assert_float(la.y).is_equal_approx(-PI * 0.5, 1e-5)
	# target cap: frame rotated by angle + PI at the end; the cap's right edge (x = 0) is the beam end and the quad
	# extends behind it (local -x, which after the PI rotation points back along the beam).
	var rect: Rect2 = BeamMath.cap_rect(36.0)
	assert_float(rect.end.x).is_equal(0.0)
	assert_float(rect.position.x).is_equal(-36.0)
	assert_float(rect.get_center().y).is_equal(0.0)
	var xf := Transform2D(la.y + PI, Vector2(10.0, -190.0))
	var far: Vector2 = xf * Vector2(rect.position.x, 0.0)
	# the cap's far edge lies on the beam axis, 36 px past the end
	assert_float(far.x).is_equal_approx(10.0, 1e-3)
	assert_float(far.y).is_equal_approx(-190.0 - 36.0, 1e-3)


func test_beam_end_distance_is_six_tenths_of_visual_radius_before_target() -> void:
	var ppm: float = ViewMath.px_per_m(1080.0)
	var vis_r: float = 60.0
	var target := Vector2.from_angle(1.0) * 12.0
	var end: Vector2 = BeamRenderer.beam_end(target, vis_r, ppm)
	var center: Vector2 = ViewMath.map_pos(target, ppm)
	assert_float(center.distance_to(end)).is_equal_approx(0.6 * vis_r, 0.01)


func test_muzzle_curves() -> void:
	assert_float(BeamMath.flash_scale(0.0)).is_equal_approx(0.6, 1e-6)
	assert_float(BeamMath.flash_scale(0.0599)).is_equal_approx(1.3, 0.01)
	assert_float(BeamMath.flash_scale(0.06)).is_equal(0.0)
	assert_float(BeamMath.cone_alpha(0.05)).is_equal(0.0)
	assert_float(BeamMath.flash_alpha(0.03)).is_equal_approx(0.5, 1e-5)
