class_name TestMenuLayout
extends GdUnitTestSuite
## MenuColumn and MenuScreen layout (M3-14): safe area and the 1080 column at the three reference sizes, and the
## stub screens' title inside them.


func _screen(size: Vector2, safe: Vector4) -> HomeScreen:
	var root: Control = auto_free(Control.new())
	root.size = size
	add_child(root)
	var s: HomeScreen = (load("res://src/ui/home/home_screen.tscn") as PackedScene).instantiate()
	root.add_child(s)
	s.size = size
	s.apply_safe_margins(safe)
	return s


func test_column_rect_math() -> void:
	var m := Vector4(10.0, 130.0, 20.0, 48.0)
	var p: Rect2 = MenuColumn.rect(Vector2(1080.0, 2341.0), m, LayoutMode.Mode.PORTRAIT)
	assert_that(p).is_equal(Rect2(10.0, 130.0, 1050.0, 2163.0))
	var w: Rect2 = MenuColumn.rect(Vector2(1990.0, 1920.0), Vector4.ZERO, LayoutMode.Mode.WIDE)
	assert_float(w.size.x).is_equal(1080.0)
	assert_float(w.get_center().x).is_equal_approx(995.0, 0.01)
	var narrow: Rect2 = MenuColumn.rect(Vector2(1000.0, 1920.0), Vector4.ZERO, LayoutMode.Mode.WIDE)
	assert_float(narrow.size.x).is_equal(1000.0)
	var degenerate: Rect2 = MenuColumn.rect(
		Vector2(100.0, 100.0), Vector4(80.0, 0.0, 80.0, 0.0), LayoutMode.Mode.PORTRAIT
	)
	assert_float(degenerate.size.x).is_equal(0.0)


func test_phone_1080x2400_title_inside_the_view() -> void:
	var s: HomeScreen = _screen(Vector2(1080.0, 2400.0), Vector4.ZERO)
	assert_int(s.layout_mode()).is_equal(LayoutMode.Mode.PORTRAIT)
	var r: Rect2 = s.column_rect()
	assert_that(r).is_equal(Rect2(0.0, 0.0, 1080.0, 2400.0))
	assert_bool(r.encloses(_title_rect(s))).is_true()


func test_cover_1080x2341_with_130_48_inset() -> void:
	var s: HomeScreen = _screen(Vector2(1080.0, 2341.0), Vector4(0.0, 130.0, 0.0, 48.0))
	var r: Rect2 = s.column_rect()
	assert_float(r.position.y).is_equal(130.0)
	assert_float(r.end.y).is_equal(2341.0 - 48.0)
	var title: Rect2 = _title_rect(s)
	assert_bool(title.position.y >= 130.0).is_true()
	assert_bool(title.end.y <= 2341.0 - 48.0).is_true()
	assert_float(s.content.position.y).is_equal(130.0)


func test_wide_1990x1920_content_is_a_1080_column() -> void:
	var s: HomeScreen = _screen(Vector2(1990.0, 1920.0), Vector4.ZERO)
	assert_int(s.layout_mode()).is_equal(LayoutMode.Mode.WIDE)
	assert_float(s.content.size.x).is_equal(1080.0)
	assert_float(s.content.position.x).is_equal_approx(455.0, 0.01)
	var title: Rect2 = _title_rect(s)
	assert_bool(Rect2(455.0, 0.0, 1080.0, 1920.0).encloses(title)).is_true()


## Every menu screen builds without missing strings; all but the title show a text heading (the title
## draws its own logo instead, M3-28).
func test_every_menu_screen_builds_with_its_title() -> void:
	var paths: Array[String] = [
		"res://src/ui/foundry/foundry_screen.tscn",
		"res://src/ui/settings/settings_screen.tscn",
		"res://src/ui/title/title_screen.tscn",
		"res://src/ui/frames/frame_bay.tscn",
		"res://src/ui/flow/save_problem_screen.tscn",
	]
	var before: int = Strings.missing_count
	for p: String in paths:
		var root: Control = auto_free(Control.new())
		root.size = Vector2(1080.0, 2400.0)
		add_child(root)
		var s: MenuScreen = (load(p) as PackedScene).instantiate()
		root.add_child(s)
		if p.ends_with("title_screen.tscn"):
			continue
		assert_bool(s.heading.visible).override_failure_message(p).is_true()
		assert_str(s.heading.text).override_failure_message(p).is_not_empty()
	assert_int(Strings.missing_count).is_equal(before)


## M3-32 emulator bug: the CORRUPT save-problem screen drew blank. Its autowrap body was first measured at a tiny
## width, the content box grew to ~5700 px and never shrank, so heading, body and START NEW PROFILE sat off-screen.
func test_save_problem_screen_fits_the_view_after_wrapping() -> void:
	var root: Control = auto_free(Control.new())
	root.size = Vector2(1080.0, 2400.0)
	add_child(root)
	var s: MenuScreen = (load("res://src/ui/flow/save_problem_screen.tscn") as PackedScene).instantiate()
	root.add_child(s)
	s.size = root.size
	s.apply_safe_margins(Vector4.ZERO)
	for i: int in 3:
		await await_idle_frame()
	var view := Rect2(Vector2.ZERO, root.size)
	assert_float(s.content.size.y).is_less_equal(2400.0)
	assert_bool(view.encloses(_title_rect(s))).is_true()
	var buttons: Array[Node] = s.content.find_children("*", "Button", true, false)
	assert_int(buttons.size()).is_greater(0)
	var b: Button = buttons[0] as Button
	assert_bool(view.encloses(Rect2(b.position + s.content.position, b.size))).is_true()


## The heading rect in the screen's pixels (content position plus the heading's own rect).
func _title_rect(s: MenuScreen) -> Rect2:
	var r: Rect2 = s.heading.get_rect()
	return Rect2(r.position + s.content.position, r.size)
