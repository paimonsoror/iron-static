class_name TestSideMargin
extends GdUnitTestSuite
## Shared menu side margin (`UiKit.MENU_SIDE_MARGIN`): no menu screen or dialog is drawn edge to edge, at the
## 1080x2400 phone, with display-cutout insets and in the near-square foldable (wide) layout.

const SCREENS: Array[String] = [
	"res://src/ui/home/home_screen.tscn",
	"res://src/ui/frames/frame_bay.tscn",
	"res://src/ui/foundry/foundry_screen.tscn",
	"res://src/ui/settings/settings_screen.tscn",
	"res://src/ui/title/title_screen.tscn",
	"res://src/ui/flow/save_problem_screen.tscn",
]


func _mount(path: String, size: Vector2, safe: Vector4) -> MenuScreen:
	var root: Control = auto_free(Control.new())
	root.size = size
	add_child(root)
	var s: MenuScreen = (load(path) as PackedScene).instantiate()
	root.add_child(s)
	s.size = size
	s.apply_safe_margins(safe)
	return s


func test_margin_constant_is_in_range_and_matches_the_pause_card() -> void:
	assert_float(UiKit.MENU_SIDE_MARGIN).is_between(40.0, 100.0 + 0.001)
	assert_float(UiKit.MENU_SIDE_MARGIN * 2.0 + PauseOverlay.CARD_W).is_less_equal(1080.0 + 0.001)


func test_column_rect_keeps_the_margin_inside_the_safe_area() -> void:
	var safe := Vector4(60.0, 100.0, 30.0, 40.0)
	var r: Rect2 = MenuColumn.rect(Vector2(1080.0, 2400.0), safe, LayoutMode.Mode.PORTRAIT)
	assert_float(r.position.x).is_greater_equal(safe.x + UiKit.MENU_SIDE_MARGIN)
	assert_float(1080.0 - r.end.x).is_greater_equal(safe.z + UiKit.MENU_SIDE_MARGIN)
	var w: Rect2 = MenuColumn.rect(Vector2(1990.0, 1920.0), Vector4.ZERO, LayoutMode.Mode.WIDE)
	assert_float(w.position.x).is_greater_equal(UiKit.MENU_SIDE_MARGIN)
	assert_float(1990.0 - w.end.x).is_greater_equal(UiKit.MENU_SIDE_MARGIN)
	assert_float(w.size.x).is_equal(MenuColumn.MAX_WIDTH)


func test_every_menu_screen_keeps_the_side_margin() -> void:
	var cases: Array = [
		[Vector2(1080.0, 2400.0), Vector4.ZERO],
		[Vector2(1080.0, 2341.0), Vector4(24.0, 130.0, 24.0, 48.0)],
		[Vector2(1990.0, 1920.0), Vector4.ZERO],
	]
	for c: Array in cases:
		var size: Vector2 = c[0]
		var safe: Vector4 = c[1]
		for path: String in SCREENS:
			var s: MenuScreen = _mount(path, size, safe)
			await await_idle_frame()
			await await_idle_frame()
			var left: float = safe.x + UiKit.MENU_SIDE_MARGIN - 0.5
			var right: float = size.x - safe.z - UiKit.MENU_SIDE_MARGIN + 0.5
			assert_float(s.content.position.x).is_greater_equal(left)
			assert_float(s.content.position.x + s.content.size.x).is_less_equal(right)
			for n: Node in s.content.find_children("*", "Control", true, false):
				var ctl: Control = n as Control
				if not ctl.is_visible_in_tree() or ctl.size.x <= 0.0 or ctl is TextureRect:  # brackets overhang plates by 2 px
					continue
				var gr: Rect2 = ctl.get_global_rect()
				var rel := Rect2(gr.position - s.global_position, gr.size)
				var msg := "%s %s at %s: %s %s" % [path.get_file(), ctl.get_class(), size, ctl.name, rel]
				assert_bool(rel.position.x >= left and rel.end.x <= right).override_failure_message(msg).is_true()


func test_home_gear_stays_inside_the_margin_column() -> void:
	var s: MenuScreen = _mount(SCREENS[0], Vector2(1080.0, 2400.0), Vector4.ZERO)
	await await_idle_frame()
	var gear: Rect2 = (s as HomeScreen).gear_button.get_rect()
	assert_float(gear.position.x).is_greater_equal(UiKit.MENU_SIDE_MARGIN)
	assert_float(1080.0 - gear.end.x).is_greater_equal(UiKit.MENU_SIDE_MARGIN)


func test_confirm_dialog_plate_keeps_the_margin() -> void:
	for size: Vector2 in [Vector2(1080.0, 2400.0), Vector2(1990.0, 1920.0)]:
		var root: Control = auto_free(Control.new())
		root.size = size
		add_child(root)
		var d := ConfirmDialog.new()
		root.add_child(d)
		d.size = size
		d.open("QUIT?", "Body text for the dialog that wraps over a couple of lines when it is long enough.")
		await await_idle_frame()
		await await_idle_frame()
		for n: Node in d.find_children("*", "Button", true, false):
			var b: Button = n as Button
			var gr: Rect2 = b.get_global_rect()
			assert_float(gr.position.x - d.global_position.x).is_greater_equal(UiKit.MENU_SIDE_MARGIN)
			assert_float(d.global_position.x + size.x - gr.end.x).is_greater_equal(UiKit.MENU_SIDE_MARGIN)
			assert_float(gr.size.y).is_greater_equal(148.0)
