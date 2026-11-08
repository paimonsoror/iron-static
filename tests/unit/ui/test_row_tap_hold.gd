class_name TestRowTapHold
extends GdUnitTestSuite
## V1-25 buying input on an UpgradeRow inside the real UpgradePanel: tap = buy 1 on release, hold = repeats,
## a drag cancels, tapping the row body toggles the tooltip (no long press). Events go through a SubViewport's GUI
## path; hold time is driven with `advance_hold` so the test does not depend on wall time.

var _vp: SubViewport = null


func _panel() -> UpgradePanel:
	_vp = auto_free(SubViewport.new())
	_vp.size = Vector2i(1080, 1000)
	add_child(_vp)
	var panel: UpgradePanel = (load("res://src/ui/upgrade_panel.tscn") as PackedScene).instantiate()
	_vp.add_child(panel)
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.best_wave_s1 = 99
	var w := SimWorld.new(cfg)
	w.economy.scrap = BigNum.from_float(1.0e9)
	panel.bind(w)
	return panel


func _center(c: Control) -> Vector2:
	var r: Rect2 = c.get_global_rect()
	return r.position + r.size * 0.5


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.global_position = pos
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_vp.push_input(e, true)


func _motion(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	_vp.push_input(e, true)


func _watch(panel: UpgradePanel) -> Array[Vector2i]:
	var got: Array[Vector2i] = []
	panel.buy_requested.connect(func(i: int, c: int) -> void: got.append(Vector2i(i, c)))
	return got


func test_tap_buys_one_on_release_only() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(100)
	var got: Array[Vector2i] = _watch(panel)
	var pos: Vector2 = _center(panel.row_at(0).get_node("%BuyButton") as Control)
	_motion(pos)
	_mouse(pos, true)
	assert_array(got).is_empty()
	_mouse(pos, false)
	assert_array(got).is_equal([Vector2i(0, 1)])


func test_hold_repeats_and_release_after_repeat_does_not_buy_again() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(100)
	var got: Array[Vector2i] = _watch(panel)
	var row: UpgradeRow = panel.row_at(0)
	var pos: Vector2 = _center(row.get_node("%BuyButton") as Control)
	_motion(pos)
	_mouse(pos, true)
	row.advance_hold(0.2)
	assert_array(got).is_empty()
	row.advance_hold(0.2)  # 0.4 s: first repeat
	assert_int(got.size()).is_equal(1)
	row.advance_hold(1.0)
	assert_int(got.size()).is_greater(3)
	var n: int = got.size()
	_mouse(pos, false)
	assert_int(got.size()).is_equal(n)
	for v: Vector2i in got:
		assert_bool([1, 10, 100].has(v.y)).is_true()


func test_hold_stops_when_the_row_is_no_longer_affordable() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(100)
	var got: Array[Vector2i] = _watch(panel)
	var row: UpgradeRow = panel.row_at(0)
	var pos: Vector2 = _center(row.get_node("%BuyButton") as Control)
	_motion(pos)
	_mouse(pos, true)
	row.advance_hold(0.4)
	assert_int(got.size()).is_equal(1)
	panel.bound_world().economy.scrap = BigNum.zero()
	panel.refresh()
	row.advance_hold(1.0)
	assert_int(got.size()).is_equal(1)
	_mouse(pos, false)
	assert_int(got.size()).is_equal(1)


func test_drag_past_the_slop_cancels_tap_and_hold() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(100)
	var got: Array[Vector2i] = _watch(panel)
	var row: UpgradeRow = panel.row_at(0)
	var pos: Vector2 = _center(row.get_node("%BuyButton") as Control)
	_motion(pos)
	_mouse(pos, true)
	_motion(pos + Vector2(0, 60))
	row.advance_hold(1.0)
	_mouse(pos + Vector2(0, 60), false)
	assert_array(got).is_empty()


func test_tapping_the_row_body_toggles_the_tooltip() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(100)
	var row: UpgradeRow = panel.row_at(0)
	var r: Rect2 = row.get_global_rect()
	var pos: Vector2 = r.position + Vector2(r.size.x * 0.3, r.size.y * 0.5)
	_motion(pos)
	_mouse(pos, true)
	assert_bool(row.is_tooltip_visible()).is_false()
	_mouse(pos, false)
	assert_bool(row.is_tooltip_visible()).is_true()
	_mouse(pos, true)
	_mouse(pos, false)
	assert_bool(row.is_tooltip_visible()).is_false()


func test_a_drag_on_the_row_body_shows_no_tooltip() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(100)
	var row: UpgradeRow = panel.row_at(0)
	var r: Rect2 = row.get_global_rect()
	var pos: Vector2 = r.position + Vector2(r.size.x * 0.3, r.size.y * 0.5)
	_motion(pos)
	_mouse(pos, true)
	_motion(pos + Vector2(0, 70))
	_mouse(pos + Vector2(0, 70), false)
	assert_bool(row.is_tooltip_visible()).is_false()
