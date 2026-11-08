class_name TestSafeArea
extends GdUnitTestSuite
## SafeArea (V1-24): window-pixel safe rect to viewport-space margins under canvas_items/expand.


func _assert_margins(got: Vector4, left: float, top: float, right: float, bottom: float) -> void:
	assert_float(got.x).is_equal_approx(left, 0.01)
	assert_float(got.y).is_equal_approx(top, 0.01)
	assert_float(got.z).is_equal_approx(right, 0.01)
	assert_float(got.w).is_equal_approx(bottom, 0.01)


func test_desktop_window_equals_safe_area_gives_zero() -> void:
	var win := Vector2(540.0, 960.0)
	var m: Vector4 = SafeArea.margins(win, Rect2(Vector2.ZERO, win), Vector2(1080.0, 1920.0))
	_assert_margins(m, 0.0, 0.0, 0.0, 0.0)


func test_cover_screen_with_top_cutout() -> void:
	# 1080x2342 screen: expand keeps 1080 wide and grows the viewport height to 2342 (scale 1.0).
	var win := Vector2(1080.0, 2342.0)
	var safe := Rect2(0.0, 130.0, 1080.0, 2342.0 - 130.0 - 48.0)  # cutout on top, 48 px gesture bar below
	var m: Vector4 = SafeArea.margins(win, safe, Vector2(1080.0, 2342.0))
	_assert_margins(m, 0.0, 130.0, 0.0, 48.0)


func test_cover_screen_scaled_window() -> void:
	# The same screen shown in a window half its size: margins stay in viewport units.
	var win := Vector2(540.0, 1171.0)
	var safe := Rect2(0.0, 65.0, 540.0, 1171.0 - 65.0)
	var m: Vector4 = SafeArea.margins(win, safe, Vector2(1080.0, 2342.0))
	_assert_margins(m, 0.0, 130.0, 0.0, 0.0)


func test_inner_near_square_screen() -> void:
	# 2152x2076 inner screen: expand fits the 1080x1920 base (scale 1.0813 on height), viewport 1990x1920.
	var win := Vector2(2152.0, 2076.0)
	var scale_f: float = 2076.0 / 1920.0
	var viewport := Vector2(2152.0 / scale_f, 1920.0)
	var safe := Rect2(60.0, 0.0, 2152.0 - 60.0 - 60.0, 2076.0 - 40.0)  # hinge-side insets, bottom bar
	var m: Vector4 = SafeArea.margins(win, safe, viewport)
	_assert_margins(m, 60.0 / scale_f, 0.0, 60.0 / scale_f, 40.0 / scale_f)


func test_larger_or_offset_safe_rect_is_clipped_to_the_window() -> void:
	var win := Vector2(1080.0, 1920.0)
	var m: Vector4 = SafeArea.margins(win, Rect2(-50.0, -50.0, 2000.0, 3000.0), Vector2(1080.0, 1920.0))
	_assert_margins(m, 0.0, 0.0, 0.0, 0.0)


func test_degenerate_inputs_give_zero() -> void:
	var vp := Vector2(1080.0, 1920.0)
	_assert_margins(SafeArea.margins(Vector2.ZERO, Rect2(0, 0, 10, 10), vp), 0.0, 0.0, 0.0, 0.0)
	_assert_margins(SafeArea.margins(Vector2(100, 100), Rect2(), vp), 0.0, 0.0, 0.0, 0.0)
	_assert_margins(SafeArea.margins(Vector2(100, 100), Rect2(500, 500, 10, 10), vp), 0.0, 0.0, 0.0, 0.0)
