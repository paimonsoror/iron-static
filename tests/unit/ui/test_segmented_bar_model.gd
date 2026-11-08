class_name TestSegmentedBarModel
extends GdUnitTestSuite
## SegmentedBar pure model (V1-16): lit counts, ramp colors, flash curve and the node's redraw behavior.


func test_integrity_fill_counts_use_ceil() -> void:
	assert_int(SegmentedBar.filled_count(100.0, 100.0, 20, true)).is_equal(20)
	assert_int(SegmentedBar.filled_count(51.0, 100.0, 20, true)).is_equal(11)
	assert_int(SegmentedBar.filled_count(50.0, 100.0, 20, true)).is_equal(10)
	assert_int(SegmentedBar.filled_count(15.0, 100.0, 20, true)).is_equal(3)
	assert_int(SegmentedBar.filled_count(1.0, 100.0, 20, true)).is_equal(1)
	assert_int(SegmentedBar.filled_count(0.0, 100.0, 20, true)).is_equal(0)
	assert_int(SegmentedBar.filled_count(500.0, 100.0, 20, true)).is_equal(20)
	assert_int(SegmentedBar.filled_count(-5.0, 100.0, 20, true)).is_equal(0)


func test_timer_fill_counts_use_floor() -> void:
	assert_int(SegmentedBar.filled_count(0.0, 720.0, 24, false)).is_equal(0)
	assert_int(SegmentedBar.filled_count(29.0, 720.0, 24, false)).is_equal(0)
	assert_int(SegmentedBar.filled_count(30.0, 720.0, 24, false)).is_equal(1)
	assert_int(SegmentedBar.filled_count(360.0, 720.0, 24, false)).is_equal(12)
	assert_int(SegmentedBar.filled_count(720.0, 720.0, 24, false)).is_equal(24)


func test_ramp_matches_cinder_ring_ramp() -> void:
	assert_bool(SegmentedBar.ramp_color(1.0).is_equal_approx(Palette.TEAL)).is_true()
	assert_bool(SegmentedBar.ramp_color(0.5).is_equal_approx(Palette.AMBER)).is_true()
	assert_bool(SegmentedBar.ramp_color(0.25).is_equal_approx(Palette.CRITICAL)).is_true()
	assert_bool(SegmentedBar.ramp_color(0.0).is_equal_approx(Palette.CRITICAL)).is_true()
	for k: int in 101:
		var f: float = float(k) / 100.0
		var a: Color = SegmentedBar.ramp_color(f)
		var b: Color = CinderView._integrity_color(f)
		assert_float(absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)).is_less(0.001)


func test_flash_strength_curve() -> void:
	assert_float(SegmentedBar.flash_strength(0.0)).is_equal(1.0)
	assert_float(SegmentedBar.flash_strength(SegmentedBar.FLASH_S)).is_equal(0.0)
	assert_float(SegmentedBar.flash_strength(1.0)).is_equal(0.0)
	assert_float(SegmentedBar.flash_strength(SegmentedBar.FLASH_S * 0.5)).is_equal_approx(0.5, 0.001)


func test_node_tracks_lit_count_and_flashes_only_on_loss() -> void:
	var bar: SegmentedBar = auto_free(SegmentedBar.new())
	bar.size = Vector2(600, 60)
	bar.ramp = true
	bar.max_value = 100.0
	add_child(bar)
	bar.value = 100.0
	assert_int(bar.lit_count()).is_equal(20)
	bar.value = 51.0
	assert_int(bar.lit_count()).is_equal(11)
	assert_bool(bar.is_processing()).is_true()
	await await_millis(300)
	assert_bool(bar.is_processing()).is_false()
	bar.value = 80.0  # a gain does not flash
	assert_int(bar.lit_count()).is_equal(16)
	assert_bool(bar.is_processing()).is_false()
	bar.animate = false
	bar.value = 10.0
	assert_bool(bar.is_processing()).is_false()
