class_name TestViewMath
extends GdUnitTestSuite

const SIZES: Array[Vector2] = [Vector2(1080.0, 1920.0), Vector2(1080.0, 2400.0)]


func test_px_per_m_at_1080() -> void:
	assert_float(ViewMath.px_per_m(1080.0)).is_equal_approx(33.75, 0.001)
	assert_float(ViewMath.px_per_m(1080.0, 38.0)).is_equal_approx(28.42, 0.01)


func test_camera_width_spans_viewport_width() -> void:
	for size: Vector2 in SIZES:
		var left: Vector2 = ViewMath.world_to_screen(Vector2(-16.0, 0.0), size)
		var right: Vector2 = ViewMath.world_to_screen(Vector2(16.0, 0.0), size)
		assert_float(left.x).is_equal_approx(0.0, 0.001)
		assert_float(right.x).is_equal_approx(size.x, 0.001)


func test_cinder_at_battle_area_center() -> void:
	for size: Vector2 in SIZES:
		var p: Vector2 = ViewMath.world_to_screen(Vector2.ZERO, size)
		var rect: Rect2 = ViewMath.battle_rect(size)
		assert_float(p.x).is_equal_approx(size.x * 0.5, 0.001)
		assert_float(p.y).is_equal_approx(size.y * 0.56 * 0.5, 0.001)
		assert_vector(p).is_equal(rect.get_center())


func test_battle_area_is_top_56_percent() -> void:
	assert_float(ViewMath.battle_height(1920.0)).is_equal_approx(1075.2, 0.01)
	assert_float(ViewMath.battle_height(2400.0)).is_equal_approx(1344.0, 0.01)


func test_world_y_is_not_flipped() -> void:
	var size: Vector2 = SIZES[0]
	var c: Vector2 = ViewMath.cinder_center(size)
	assert_float(ViewMath.world_to_screen(Vector2(0.0, 10.0), size).y).is_greater(c.y)


func test_38_m_spans_viewport_width() -> void:
	for size: Vector2 in SIZES:
		var left: Vector2 = ViewMath.world_to_screen(Vector2(-19.0, 0.0), size, 38.0)
		var right: Vector2 = ViewMath.world_to_screen(Vector2(19.0, 0.0), size, 38.0)
		assert_float(left.x).is_equal_approx(0.0, 0.001)
		assert_float(right.x).is_equal_approx(size.x, 0.001)


func test_map_pos_standoff_values() -> void:
	var ppm: float = ViewMath.px_per_m(1080.0)
	assert_float(ViewMath.map_pos(Vector2(2.0, 0.0), ppm).x).is_equal_approx(ppm * 2.0 + ViewMath.STANDOFF_PX, 0.001)
	assert_float(ViewMath.map_pos(Vector2(0.0, 10.0), ppm).y).is_equal_approx(ppm * 10.0, 0.001)
	assert_float(ViewMath.map_pos(Vector2(30.0, 0.0), ppm).x).is_equal_approx(ppm * 30.0, 0.001)
	assert_vector(ViewMath.map_pos(Vector2(0.0, 0.0005), ppm)).is_equal(Vector2.ZERO)
	# inside 2 m the full stand-off applies
	assert_float(ViewMath.map_dist(1.0, ppm)).is_equal_approx(ppm + ViewMath.STANDOFF_PX, 0.001)


func test_map_pos_strictly_increasing_and_direction_preserved() -> void:
	for ppm: float in [ViewMath.px_per_m(1080.0), ViewMath.px_per_m(1080.0, 38.0)]:
		var prev: float = -1.0
		for k: int in range(1, 601):
			var d: float = float(k) * 0.1
			var dir: Vector2 = Vector2.from_angle(0.7)
			var p: Vector2 = ViewMath.map_pos(dir * d, ppm)
			assert_float(p.length()).is_greater(prev)
			assert_float(absf(p.angle() - 0.7)).is_less(1e-6)
			prev = p.length()
		assert_float(ViewMath.map_factor(3.0, 4.0, ppm) * 5.0).is_equal_approx(ViewMath.map_dist(5.0, ppm), 0.001)


func test_type_scale_and_walker_is_smaller() -> void:
	var ppm: float = ViewMath.px_per_m(1080.0)
	assert_float(ViewMath.type_scale(0)).is_equal(1.5)
	assert_float(ViewMath.type_scale(2)).is_equal_approx(1.2, 1e-6)
	# slot table: skitter body radius 32 px, walker 70 px x visual_scale 0.8 = 56 px (read from ArtSlots)
	assert_float(ViewMath.visual_radius_px(0.6, 0, ppm)).is_equal_approx(32.0, 0.01)
	assert_float(ViewMath.visual_radius_px(1.4, 2, ppm)).is_equal_approx(56.0, 0.01)
	assert_float(ViewMath.type_scale(99)).is_equal(1.5)


func test_beam_end_pulled_back_on_the_line_to_the_target() -> void:
	var ppm: float = ViewMath.px_per_m(1080.0)
	var target := Vector2.from_angle(0.4) * 10.0
	var vis_r: float = ViewMath.visual_radius_px(0.6, 0, ppm)
	var end: Vector2 = BeamRenderer.beam_end(target, vis_r, ppm)
	assert_float(end.length()).is_equal_approx(ViewMath.map_dist(10.0, ppm) - 0.6 * vis_r, 0.001)
	assert_float(absf(end.angle() - 0.4)).is_less(1e-6)


func test_enemy_cull_rect_covers_battle_rect_with_margin() -> void:
	var ppm: float = ViewMath.px_per_m(1080.0)
	var rect := Rect2(-540.0, -672.0, 1080.0, 1344.0)
	var c: Rect2 = EnemyRenderer.cull_rect_for(rect, ppm)
	assert_bool(c.encloses(rect)).is_true()
	assert_float(rect.position.x - c.position.x).is_greater_equal(ViewMath.visual_radius_px(3.0, 4, ppm))


func test_type_scale_reads_the_slot_table() -> void:
	for t: int in ViewMath.ENEMY_SLOTS.size():
		var vs: float = ArtSlots.slot(ViewMath.ENEMY_SLOTS[t]).visual_scale
		assert_float(ViewMath.type_scale(t)).is_equal_approx(ViewMath.VISUAL_SCALE * vs, 1e-6)
	assert_float(ViewMath.slot_visual_scale(2)).is_equal_approx(0.8, 1e-6)
	assert_float(ViewMath.body_radius_px(2, ViewMath.REF_PPM)).is_equal_approx(56.0, 1e-4)
	assert_float(ViewMath.body_radius_px(2, ViewMath.REF_PPM * 2.0)).is_equal_approx(112.0, 1e-3)


func test_contact_standoff_clears_the_armor_ring_per_type() -> void:
	var ppm: float = ViewMath.px_per_m(1080.0)
	var armor: float = 2.0 * ppm * ViewMath.VISUAL_SCALE  # about 101 px
	var last: float = -1.0
	for t: int in ViewMath.ENEMY_SLOTS.size():
		var r: float = ViewMath.body_radius_px(t, ppm)
		var s: float = ViewMath.contact_standoff_px(r, 2.0, ppm)
		var center: float = ViewMath.map_dist(2.0, ppm, s)
		# the sprite edge rests just outside the ring: gap = CONTACT_GAP_PX
		assert_float(center - r - armor).is_equal_approx(ViewMath.CONTACT_GAP_PX, 0.01)
		assert_float(s).is_less(ViewMath.STANDOFF_SPAN_M * ppm)
		# still strictly increasing with distance
		var prev: float = -1.0
		for k: int in range(1, 601):
			var d: float = ViewMath.map_dist(float(k) * 0.1, ppm, s)
			assert_float(d).is_greater(prev)
			prev = d
		last = maxf(last, s)
	# heavier sprites need more stand-off than skitters
	assert_float(ViewMath.contact_standoff_px(56.0, 2.0, ppm)).is_greater(ViewMath.contact_standoff_px(32.0, 2.0, ppm))
	assert_float(last).is_greater(0.0)


func test_beam_end_with_per_type_standoff() -> void:
	var ppm: float = ViewMath.px_per_m(1080.0)
	var target := Vector2.from_angle(0.4) * 2.0
	var end: Vector2 = BeamRenderer.beam_end(target, 50.0, ppm, 100.0)
	assert_float(end.length()).is_equal_approx(ViewMath.map_dist(2.0, ppm, 100.0) - 0.6 * 50.0, 0.001)
