class_name TestViewMath
extends GdUnitTestSuite

const SIZES: Array[Vector2] = [Vector2(1080.0, 1920.0), Vector2(1080.0, 2400.0)]


func test_px_per_m_at_1080() -> void:
	assert_float(ViewMath.px_per_m(1080.0)).is_equal_approx(28.42, 0.01)


func test_38_m_spans_viewport_width() -> void:
	for size: Vector2 in SIZES:
		var left: Vector2 = ViewMath.world_to_screen(Vector2(-19.0, 0.0), size)
		var right: Vector2 = ViewMath.world_to_screen(Vector2(19.0, 0.0), size)
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
