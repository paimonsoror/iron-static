class_name TestCinderWedges
extends GdUnitTestSuite


func _count(arr: PackedInt32Array, value: int) -> int:
	var n: int = 0
	for v: int in arr:
		if v == value:
			n += 1
	return n


func _indices(arr: PackedInt32Array, value: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in arr.size():
		if arr[i] == value:
			out.append(i)
	return out


func test_band_0_all_intact() -> void:
	var s: PackedInt32Array = CinderWedges.states(0)
	assert_int(s.size()).is_equal(12)
	assert_int(_count(s, 0)).is_equal(12)
	assert_int(_count(s, 1)).is_equal(0)
	assert_int(_count(s, 2)).is_equal(0)


func test_band_1_three_charred() -> void:
	var s: PackedInt32Array = CinderWedges.states(1)
	assert_int(_count(s, 0)).is_equal(9)
	assert_int(_count(s, 1)).is_equal(3)
	assert_int(_count(s, 2)).is_equal(0)
	assert_array(_indices(s, 1)).is_equal([2, 7, 10])


func test_band_2_eight_gone_four_charred() -> void:
	var s: PackedInt32Array = CinderWedges.states(2)
	assert_int(_count(s, 0)).is_equal(0)
	assert_int(_count(s, 1)).is_equal(4)
	assert_int(_count(s, 2)).is_equal(8)
	assert_array(_indices(s, 2)).is_equal([0, 2, 3, 5, 7, 8, 10, 11])
	assert_array(_indices(s, 1)).is_equal([1, 4, 6, 9])


func test_band_3_all_gone() -> void:
	var s: PackedInt32Array = CinderWedges.states(3)
	assert_int(_count(s, 2)).is_equal(12)
	assert_int(_count(s, 0)).is_equal(0)
	assert_int(_count(s, 1)).is_equal(0)


func test_invalid_bands_are_clamped() -> void:
	assert_array(CinderWedges.states(-5)).is_equal(CinderWedges.states(0))
	assert_array(CinderWedges.states(4)).is_equal(CinderWedges.states(3))
	assert_array(CinderWedges.states(99)).is_equal(CinderWedges.states(3))


func test_integrity_color_endpoints() -> void:
	assert_bool(CinderView._integrity_color(1.0).is_equal_approx(Palette.TEAL)).is_true()
	assert_bool(CinderView._integrity_color(0.5).is_equal_approx(Palette.AMBER)).is_true()
	assert_bool(CinderView._integrity_color(0.1).is_equal_approx(Palette.CRITICAL)).is_true()
