class_name TestPalette
extends GdUnitTestSuite

## Spot checks against GDD 07 section 5.2 (hex values).


func _same(a: Color, hex: String) -> bool:
	return a.is_equal_approx(Color.html(hex))


func test_gdd_hex_spot_checks() -> void:
	assert_bool(_same(Palette.VOID, "#07090C")).is_true()
	assert_bool(_same(Palette.AMBER, "#FFB000")).is_true()
	assert_bool(_same(Palette.SKIN, "#D9A383")).is_true()
	assert_bool(_same(Palette.CHAR, "#3A2A22")).is_true()
	assert_bool(_same(Palette.ENEMY_OUTLINE, "#FF2D4B")).is_true()
	assert_bool(_same(Palette.ENEMY_FILL, "#2A0A10")).is_true()
	assert_bool(_same(Palette.ENEMY_FIRE, "#FF4FD8")).is_true()
	assert_bool(_same(Palette.TEAL, "#2EE6D6")).is_true()
	assert_bool(_same(Palette.FRAME, "#8FA3B0")).is_true()
	assert_bool(_same(Palette.DATA, "#5BC8FF")).is_true()
