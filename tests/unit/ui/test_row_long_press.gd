class_name TestRowLongPress
extends GdUnitTestSuite
## Long-press tooltip of an UpgradeRow inside the real UpgradePanel ScrollContainer (M2-16 follow-up: on the
## emulator the tooltip never showed with adb-injected presses). The panel lives in a SubViewport and events go
## through that viewport's GUI path (the headless root window does not route pushed mouse events to controls).

const HOLD_MS: int = 600

var _vp: SubViewport = null


func _panel() -> UpgradePanel:
	_vp = auto_free(SubViewport.new())
	_vp.size = Vector2i(1080, 1000)
	add_child(_vp)
	var packed: PackedScene = load("res://src/ui/upgrade_panel.tscn")
	var panel: UpgradePanel = packed.instantiate()
	_vp.add_child(panel)
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.best_wave_s1 = 99
	panel.bind(SimWorld.new(cfg))
	return panel


func _press_point(row: UpgradeRow) -> Vector2:
	var r: Rect2 = row.get_global_rect()
	return r.position + Vector2(r.size.x * 0.4, r.size.y * 0.5)


func _move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	_vp.push_input(e, true)


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	_vp.push_input(e, true)


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.global_position = pos
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_vp.push_input(e, true)


func test_mouse_press_and_hold_shows_tooltip() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(100)
	var row: UpgradeRow = panel.row_at(0)
	var pos: Vector2 = _press_point(row)
	_move(pos)
	await await_millis(50)
	_mouse(pos, true)
	await await_millis(HOLD_MS)
	assert_bool(row.is_tooltip_visible()).is_true()
	_mouse(pos, false)


func test_touch_press_and_hold_shows_tooltip() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(100)
	var row: UpgradeRow = panel.row_at(0)
	var pos: Vector2 = _press_point(row)
	_touch(pos, true)
	await await_millis(HOLD_MS)
	assert_bool(row.is_tooltip_visible()).is_true()
	_touch(pos, false)


func test_short_tap_shows_no_tooltip() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(100)
	var row: UpgradeRow = panel.row_at(0)
	var pos: Vector2 = _press_point(row)
	_move(pos)
	await await_millis(50)
	_mouse(pos, true)
	await await_millis(100)
	_mouse(pos, false)
	await await_millis(HOLD_MS)
	assert_bool(row.is_tooltip_visible()).is_false()


func test_touch_drag_cancels_the_press() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(100)
	var row: UpgradeRow = panel.row_at(0)
	var pos: Vector2 = _press_point(row)
	_touch(pos, true)
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = pos + Vector2(0, 80)
	d.relative = Vector2(0, 80)
	_vp.push_input(d, true)
	await await_millis(HOLD_MS)
	assert_bool(row.is_tooltip_visible()).is_false()
	_touch(pos, false)
