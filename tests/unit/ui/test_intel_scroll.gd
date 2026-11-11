class_name TestIntelScroll
extends GdUnitTestSuite
## Pixel report (0.5.0-beta.1): the INTEL tab (STATS and WAVE) did not scroll by touch. The read-only cards were
## PanelContainers (mouse_filter STOP), which consumed the gesture before the panel's ScrollContainer saw it.
## Events go through a SubViewport's GUI path starting on a card. Headless Godot does not scroll a ScrollContainer from
## pushed touch drags (even a bare one), so the touch half proves the gesture REACHES the ScrollContainer (the
## ScrollContainer's `gui_input` sees the ScreenTouch and ScreenDrag) plus a structural check that no card control
## up to the scroller stops mouse events. The mouse wheel already worked before the fix (Godot routes it differently);
## its test guards the desktop editor path.

var _vp: SubViewport = null


func _panel() -> UpgradePanel:
	_vp = auto_free(SubViewport.new())
	_vp.size = Vector2i(1080, 1920)
	add_child(_vp)
	var panel: UpgradePanel = (load("res://src/ui/upgrade_panel.tscn") as PackedScene).instantiate()
	_vp.add_child(panel)
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.best_wave_s1 = 99
	var w := SimWorld.new(cfg)
	w.economy.scrap = BigNum.from_float(1.0e9)
	panel.bind(w)
	return panel


func _scroll(panel: UpgradePanel) -> ScrollContainer:
	return panel.get_node("%Scroll")


## A card's on-screen point: its center, or its top-left part when the center is below the visible scroll area.
func _grab(panel: UpgradePanel, c: Control) -> Vector2:
	var area: Rect2 = _scroll(panel).get_global_rect()
	var p: Vector2 = _center(c)
	assert_bool(area.has_point(p)).is_true()
	return p


func _center(c: Control) -> Vector2:
	var r: Rect2 = c.get_global_rect()
	return r.position + r.size * 0.5


func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	_vp.push_input(e, true)


## A finger swipe upward by `dist` px starting at `start`, in small steps (raw touch events only).
func _swipe_up(start: Vector2, dist: float) -> void:
	_touch(start, true)
	var prev: Vector2 = start
	for i: int in 5:
		var e := InputEventScreenDrag.new()
		e.index = 0
		e.position = start + Vector2(0.0, -dist * float(i + 1) / 5.0)
		e.relative = e.position - prev
		e.screen_relative = e.relative
		_vp.push_input(e, true)
		prev = e.position
	_touch(prev, false)


func _wheel_down(pos: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_DOWN
	e.position = pos
	e.global_position = pos
	e.pressed = true
	_vp.push_input(e, true)


func _overflows(panel: UpgradePanel) -> bool:
	var sc: ScrollContainer = _scroll(panel)
	return sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page > 50.0


func _cards(panel: UpgradePanel, wave: bool) -> Array[Control]:
	var p: IntelPanel = panel.intel_hub().wave_panel() if wave else panel.intel_panel()
	var out: Array[Control] = []
	for child: Node in p.get_children():
		if child is PanelContainer and (child as PanelContainer).visible:
			out.append(child as Control)
	return out


func _intel(wave: bool) -> UpgradePanel:
	var panel: UpgradePanel = _panel()
	panel.set_tab("intel")
	assert_bool(panel.intel_hub().set_sub("wave" if wave else "stats")).is_true()
	return panel


## Records the event classes the ScrollContainer sees.
func _spy(panel: UpgradePanel) -> Array[String]:
	var seen: Array[String] = []
	_scroll(panel).gui_input.connect(func(ev: InputEvent) -> void: seen.append(ev.get_class()))
	return seen


func _stops_between(c: Control, stop_at: Node) -> Array[String]:
	var bad: Array[String] = []
	var n: Node = c
	while n != null and n != stop_at:
		var ctl: Control = n as Control
		if ctl != null and ctl.mouse_filter == Control.MOUSE_FILTER_STOP:
			bad.append(str(ctl.get_path()))
		n = n.get_parent()
	return bad


func test_touch_drag_on_a_card_reaches_the_scroll_container() -> void:
	for wave: bool in [false, true]:
		var panel: UpgradePanel = _intel(wave)
		await await_millis(700)
		assert_bool(_overflows(panel)).is_true()
		var cards: Array[Control] = _cards(panel, wave)
		assert_bool(cards.size() >= 3).is_true()
		var seen: Array[String] = _spy(panel)
		_swipe_up(_grab(panel, cards[0]), 50.0)
		assert_bool(seen.has("InputEventScreenTouch")).is_true()
		assert_bool(seen.has("InputEventScreenDrag")).is_true()


func test_no_card_control_stops_mouse_events_below_the_scroller() -> void:
	for wave: bool in [false, true]:
		var panel: UpgradePanel = _intel(wave)
		await await_millis(700)
		for card: Control in _cards(panel, wave):
			assert_array(_stops_between(card, _scroll(panel))).is_empty()
			for d: Node in card.find_children("*", "Control", true, false):
				assert_array(_stops_between(d as Control, _scroll(panel))).is_empty()


func test_mouse_wheel_over_intel_cards_scrolls_the_list() -> void:
	for wave: bool in [false, true]:
		var panel: UpgradePanel = _intel(wave)
		await await_millis(700)
		_scroll(panel).scroll_vertical = 0
		_wheel_down(_grab(panel, _cards(panel, wave)[0]))
		assert_int(_scroll(panel).scroll_vertical).is_greater(0)


func test_upgrade_rows_still_pass_touch_and_wheel_to_the_scroller_and_do_not_buy() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(700)
	var got: Array[Vector2i] = []
	panel.buy_requested.connect(func(i: int, c: int) -> void: got.append(Vector2i(i, c)))
	var row: UpgradeRow = panel.row_at(0)
	var start: Vector2 = _center(row.get_node("%NameLabel") as Control)
	var seen: Array[String] = _spy(panel)
	_swipe_up(start, 50.0)
	assert_bool(seen.has("InputEventScreenDrag")).is_true()
	assert_array(got).is_empty()
	assert_bool(row.is_tooltip_visible()).is_false()
	if _overflows(panel):
		_wheel_down(start)
		assert_int(_scroll(panel).scroll_vertical).is_greater(0)


func test_tap_on_an_upgrade_row_body_still_toggles_the_tooltip() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(700)
	var row: UpgradeRow = panel.row_at(0)
	var pos: Vector2 = _center(row.get_node("%NameLabel") as Control)
	_touch(pos, true)
	_touch(pos, false)
	assert_bool(row.is_tooltip_visible()).is_true()
