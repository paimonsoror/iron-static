class_name TestFieldRect
extends GdUnitTestSuite
## V1-28: the battle view's field is a rect. Horizontal insets center Cinder in the field column and the camera fit
## uses the field's limiting dimension; set_field_insets keeps working as the vertical wrapper.

const SCENE: PackedScene = preload("res://src/view/battle_view.tscn")
const INNER := Vector2(1990.0, 1920.0)


func _view(viewport: Vector2) -> BattleView:
	var view: BattleView = auto_free(SCENE.instantiate())
	add_child(view)
	view.layout(viewport)
	view.bind(SimWorld.new(SimConfigLoader.load_default(1)))
	return view


func test_field_rect_math_with_side_insets() -> void:
	var f: Rect2 = ViewMath.field_rect(INNER, 252.0, 0.0, 0.0, 796.0)
	assert_float(f.position.x).is_equal(0.0)
	assert_float(f.size.x).is_equal(1194.0)
	assert_float(f.position.y).is_equal(252.0)
	assert_float(f.size.y).is_equal(1668.0)
	var same: Rect2 = ViewMath.field_rect(Vector2(1080.0, 2400.0), 252.0, 617.0)
	assert_vector(same.size).is_equal(Vector2(1080.0, 1531.0))  # unchanged defaults


func test_fit_width_uses_the_limiting_field_dimension() -> void:
	# 1194 x 1668 field in a 1990 wide viewport: the width limits, so the 52 m circle spans 1194 px
	var w: float = ViewMath.fit_width_m(24.0, 52.0, INNER, Vector2(1194.0, 1668.0))
	assert_float(w).is_equal_approx(52.0 * 1990.0 / 1194.0, 1e-3)
	assert_float(ViewMath.px_per_m(1990.0, w) * 52.0).is_equal_approx(1194.0, 0.5)
	# a tall narrow field limits by width too; a squat one by height (old behavior)
	assert_float(ViewMath.fit_width_m(24.0, 52.0, INNER, Vector2(1990.0, 1051.0))).is_equal_approx(
		52.0 * 1990.0 / 1051.0, 1e-3
	)
	# ZERO field size and a full-width field agree
	var a: float = ViewMath.fit_width_m(24.0, 52.0, Vector2(1080.0, 1920.0))
	var b: float = ViewMath.fit_width_m(24.0, 52.0, Vector2(1080.0, 1920.0), Vector2(1080.0, 1075.2))
	assert_float(a).is_equal_approx(b, 1e-4)


func test_cinder_centers_in_the_field_column() -> void:
	var view: BattleView = _view(INNER)
	view.set_field_rect(Rect2(0.0, 252.0, 1194.0, 1668.0))
	view.render(0.5)
	assert_vector(view.position).is_equal(Vector2(597.0, 1086.0))
	assert_float(view.camera_m()).is_equal_approx(52.0 * 1990.0 / 1194.0, 1e-3)
	# the 52 m circle fits the column width, so the sprite factor stays at 85 percent
	assert_float(view.sprite_factor()).is_equal_approx(0.85, 1e-4)
	assert_vector(view.field_rect().size).is_equal(Vector2(1194.0, 1668.0))
	# left inset: the column starts to the right of 100 px
	view.set_field_rect(Rect2(100.0, 252.0, 1000.0, 1668.0))
	assert_vector(view.position).is_equal(Vector2(600.0, 1086.0))


func test_set_field_insets_keeps_the_side_insets_and_negative_clears_vertical() -> void:
	var view: BattleView = _view(INNER)
	view.set_field_rect(Rect2(0.0, 252.0, 1194.0, 1668.0))
	view.set_field_insets(300.0, 0.0)
	assert_vector(view.field_rect().size).is_equal(Vector2(1194.0, 1620.0))
	var portrait: BattleView = _view(Vector2(1080.0, 2400.0))
	portrait.set_field_insets(365.0, 1055.0)
	assert_vector(portrait.position).is_equal(Vector2(540.0, 855.0))
	portrait.set_field_insets(-1.0, -1.0)
	assert_vector(portrait.position).is_equal(Vector2(540.0, 672.0))


func test_field_edges_survive_a_viewport_resize_until_the_next_rect() -> void:
	var view: BattleView = _view(INNER)
	view.set_field_rect(Rect2(0.0, 252.0, 1194.0, 1668.0))
	view.layout(Vector2(1600.0, 1920.0))
	# insets are kept (right 796 px): the HUD reports the new rect right after in the real scene
	assert_float(view.field_rect().end.x).is_equal(804.0)
	view.set_field_rect(Rect2(0.0, 252.0, 900.0, 1668.0))
	assert_vector(view.position).is_equal(Vector2(450.0, 1086.0))
