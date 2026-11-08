class_name TestLayoutMode
extends GdUnitTestSuite
## V1-28: LayoutMode thresholds and hysteresis, and the pure rect math of the wide layout.

const P := LayoutMode.Mode.PORTRAIT
const W := LayoutMode.Mode.WIDE


func test_phone_and_foldable_aspects() -> void:
	assert_int(LayoutMode.pick(Vector2(1080.0, 1920.0), P)).is_equal(P)  # 0.5625
	assert_int(LayoutMode.pick(Vector2(1080.0, 2400.0), P)).is_equal(P)  # 0.45
	assert_int(LayoutMode.pick(Vector2(1080.0, 2341.0), P)).is_equal(P)  # cover screen
	assert_int(LayoutMode.pick(Vector2(1440.0, 1920.0), P)).is_equal(P)  # 3:4 tablet: 0.75 stays portrait
	assert_int(LayoutMode.pick(Vector2(1990.0, 1920.0), P)).is_equal(W)  # inner screen
	assert_int(LayoutMode.pick(Vector2(1600.0, 1920.0), P)).is_equal(W)  # 0.83
	assert_int(LayoutMode.pick(Vector2(2400.0, 1080.0), P)).is_equal(W)  # landscape


func test_enter_and_exit_thresholds_differ() -> void:
	var enter: float = LayoutMode.WIDE_ENTER
	var leave: float = LayoutMode.PORTRAIT_ENTER
	assert_float(enter).is_greater(LayoutMode.THRESHOLD)
	assert_float(leave).is_less(LayoutMode.THRESHOLD)
	var just_below := Vector2(1920.0 * (enter - 0.001), 1920.0)
	var just_above := Vector2(1920.0 * (leave + 0.001), 1920.0)
	assert_int(LayoutMode.pick(just_below, P)).is_equal(P)
	assert_int(LayoutMode.pick(Vector2(1920.0 * (enter + 0.001), 1920.0), P)).is_equal(W)
	assert_int(LayoutMode.pick(just_above, W)).is_equal(W)  # inside the band a wide layout stays wide
	assert_int(LayoutMode.pick(Vector2(1920.0 * (leave - 0.001), 1920.0), W)).is_equal(P)


func test_a_resize_sweep_across_the_threshold_does_not_flap() -> void:
	# widen then narrow in 1 px steps: exactly one switch each way
	var mode: LayoutMode.Mode = P
	var switches: int = 0
	var widths: Array[float] = []
	for w: int in range(1300, 1700):
		widths.append(float(w))
	for w: int in range(1700, 1300, -1):
		widths.append(float(w))
	for w: float in widths:
		var next: LayoutMode.Mode = LayoutMode.pick(Vector2(w, 1920.0), mode)
		if next != mode:
			switches += 1
			mode = next
	assert_int(switches).is_equal(2)
	assert_int(mode).is_equal(P)


func test_degenerate_sizes_keep_the_current_mode() -> void:
	assert_int(LayoutMode.pick(Vector2.ZERO, W)).is_equal(W)
	assert_int(LayoutMode.pick(Vector2(100.0, 0.0), P)).is_equal(P)


func test_panel_width_clamps() -> void:
	assert_float(LayoutRects.panel_width(1990.0)).is_equal_approx(796.0, 0.01)
	assert_float(LayoutRects.panel_width(1600.0)).is_equal(LayoutRects.PANEL_MIN_PX)
	assert_float(LayoutRects.panel_width(2400.0)).is_equal(LayoutRects.PANEL_MAX_PX)
	assert_float(LayoutRects.panel_width(1000.0)).is_equal(500.0)  # never more than half the viewport


func test_wide_rects_without_margins() -> void:
	var vp := Vector2(1990.0, 1920.0)
	var panel: Rect2 = LayoutRects.panel_rect(vp, Vector4.ZERO)
	assert_float(panel.end.x).is_equal_approx(1990.0, 0.01)
	assert_float(panel.size.y).is_equal(1920.0)
	assert_float(panel.size.x / vp.x).is_between(0.34, 0.42)
	var bar: Rect2 = LayoutRects.hud_bar(vp, Vector4.ZERO)
	assert_float(bar.size.x).is_equal(LayoutRects.HUD_MAX_PX)  # column 1194 wide: capped
	assert_float(bar.end.x).is_less(panel.position.x)
	assert_float(bar.position.x).is_greater(0.0)
	var field: Rect2 = LayoutRects.field(vp, Vector4.ZERO, 252.0)
	assert_float(field.position.x).is_equal(0.0)
	assert_float(field.end.x).is_equal_approx(panel.position.x, 0.01)
	assert_float(field.position.y).is_equal(252.0)
	assert_float(field.end.y).is_equal(1920.0)


func test_wide_rects_honor_safe_margins() -> void:
	var vp := Vector2(1990.0, 1920.0)
	var m := Vector4(40.0, 100.0, 60.0, 50.0)  # left, top, right, bottom
	var panel: Rect2 = LayoutRects.panel_rect(vp, m)
	assert_float(panel.end.x).is_equal_approx(1930.0, 0.01)
	assert_float(panel.position.y).is_equal(100.0)
	assert_float(panel.end.y).is_equal(1870.0)
	var col: Rect2 = LayoutRects.hud_column(vp, m)
	assert_float(col.position.x).is_equal(40.0)
	assert_float(col.end.x).is_equal_approx(panel.position.x, 0.01)
	var narrow: Rect2 = LayoutRects.hud_bar(Vector2(1600.0, 1920.0), m)
	assert_float(narrow.size.x).is_less_equal(LayoutRects.HUD_MAX_PX)
	assert_float(narrow.position.x).is_greater_equal(40.0)
	assert_float(LayoutRects.field(vp, m, 352.0).end.y).is_equal(1870.0)
