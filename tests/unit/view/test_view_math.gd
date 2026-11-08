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
	# skitter 0.6 m -> about 30 px radius, walker 1.4 m -> about 57 px
	assert_float(ViewMath.visual_radius_px(0.6, 0, ppm)).is_equal_approx(30.4, 0.1)
	assert_float(ViewMath.visual_radius_px(1.4, 2, ppm)).is_equal_approx(56.7, 0.1)
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
