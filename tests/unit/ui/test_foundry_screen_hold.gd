class_name TestFoundryScreenHold
extends GdUnitTestSuite
## Tap and hold buying on the Foundry rows (M3-16): the run panel's hold logic (`RepeatBuyModel`) driven with a fake
## clock (`advance_hold`) through real mouse events on a SubViewport.

var _vp: SubViewport = null
var _screen: FoundryScreen = null
var _spy: SpyAudioDirector = null
var _bought: Array[Vector2i] = []


func before_test() -> void:
	_spy = auto_free(SpyAudioDirector.new())
	AudioHooks.override = _spy
	Game.visual.reduce_motion = true
	_bought = []


func after_test() -> void:
	AudioHooks.override = null
	Game.visual.reduce_motion = false


func _no_save() -> bool:
	return true


func _noop() -> void:
	pass


func _on_bought(idx: int, count: int) -> void:
	_bought.append(Vector2i(idx, count))


func _make(data: BigNum, maxed_laser: bool = false) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.fresh(0, "test")
	p.data = data
	p.runs_total = 1
	@warning_ignore("return_value_discarded")
	FoundryIntroFlag.set_hidden(p, true)  # the explainer dialog would swallow the touches
	if maxed_laser:
		p.set_foundry_level("laser_output", 200)
	_vp = auto_free(SubViewport.new())
	_vp.size = Vector2i(1080, 2400)
	add_child(_vp)
	_screen = (load("res://src/ui/foundry/foundry_screen.tscn") as PackedScene).instantiate()
	_screen.use_profile(p)
	_screen.use_save_hooks(_noop, _no_save)
	_vp.add_child(_screen)
	_screen.size = Vector2(1080.0, 2400.0)
	_screen.enter()
	for i: int in _screen.row_count():
		_screen.row_at(i).buy_pressed.connect(_on_bought)
	return p


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


func _press(row: FoundryRow) -> Vector2:
	var pos: Vector2 = _center(row.buy_button())
	_motion(pos)
	_mouse(pos, true)
	return pos


func test_tap_buys_exactly_one_level_on_release() -> void:
	var p: PlayerProfile = _make(BigNum.from_int(1000))
	await await_millis(60)
	var pos: Vector2 = _press(_screen.row_at(0))
	assert_int(p.foundry_level("laser_output")).is_equal(0)
	_mouse(pos, false)
	assert_int(p.foundry_level("laser_output")).is_equal(1)
	assert_array(_bought).is_equal([Vector2i(0, 1)])
	assert_int(_spy.buy_steps).is_equal(1)
	assert_int(_spy.buy_ends).is_equal(1)


func test_a_3_5_second_hold_buys_the_run_panels_counts() -> void:
	var p: PlayerProfile = _make(BigNum.from_float(1.0e12))
	await await_millis(60)
	var row: FoundryRow = _screen.row_at(0)
	var pos: Vector2 = _press(row)
	var reference := RepeatBuyModel.new()
	var expected: Array[int] = []
	var t: float = 0.0
	for step: int in 35:
		assert_int(step).is_greater_equal(0)
		t += 0.1
		row.advance_hold(0.1)
		var due: Vector2i = reference.poll(t)
		for k: int in due.x:
			assert_int(k).is_greater_equal(0)
			expected.append(due.y)
	var counts: Array[int] = []
	for v: Vector2i in _bought:
		counts.append(v.y)
	assert_array(counts).is_equal(expected)
	assert_int(counts[0]).is_equal(1)
	assert_int(counts.back()).is_equal(10)
	var n: int = _bought.size()
	_mouse(pos, false)
	assert_int(_bought.size()).is_equal(n)  # the release after repeats buys nothing more
	var levels: int = 0
	for c: int in counts:
		levels += c
	assert_int(p.foundry_level("laser_output")).is_equal(levels)
	assert_int(_spy.buy_ends).is_equal(1)


func test_a_drag_past_24_px_cancels() -> void:
	var p: PlayerProfile = _make(BigNum.from_int(1000))
	await await_millis(60)
	var row: FoundryRow = _screen.row_at(0)
	var pos: Vector2 = _press(row)
	_motion(pos + Vector2(0.0, 40.0))
	row.advance_hold(1.0)
	_mouse(pos + Vector2(0.0, 40.0), false)
	assert_array(_bought).is_empty()
	assert_int(p.foundry_level("laser_output")).is_equal(0)


func test_partial_affordability_buys_what_it_can_then_denies() -> void:
	var p: PlayerProfile = _make(BigNum.from_int(100))  # laser costs 20, 22, 24, 27, 29...: 4 levels fit
	await await_millis(60)
	var row: FoundryRow = _screen.row_at(0)
	var pos: Vector2 = _press(row)
	for i: int in 60:
		assert_int(i).is_greater_equal(0)
		row.advance_hold(0.1)
	_mouse(pos, false)
	assert_int(p.foundry_level("laser_output")).is_greater(1)
	assert_bool(p.data.lt(BigNum.from_int(30))).is_true()
	assert_int(_spy.count("sfx_ui_deny")).is_greater_equal(1)
	assert_int(_spy.buy_ends).is_equal(1)


func test_pressing_an_unaffordable_row_denies_and_buys_nothing() -> void:
	var p: PlayerProfile = _make(BigNum.from_int(5))
	await await_millis(60)
	var pos: Vector2 = _press(_screen.row_at(0))
	_mouse(pos, false)
	assert_int(p.foundry_level("laser_output")).is_equal(0)
	assert_int(_spy.count("sfx_ui_deny")).is_equal(1)
	assert_int(_spy.buy_steps).is_equal(0)


func test_a_row_at_the_cap_shows_max_and_cannot_be_pressed() -> void:
	@warning_ignore("return_value_discarded")
	_make(BigNum.from_int(1000), true)
	await await_millis(60)
	var button: Button = _screen.row_at(0).buy_button()
	assert_bool(button.disabled).is_true()
	assert_str(button.text).is_equal("MAX")


func test_row_body_tap_toggles_the_formula_tooltip() -> void:
	@warning_ignore("return_value_discarded")
	_make(BigNum.from_int(1000))
	await await_millis(60)
	var row: FoundryRow = _screen.row_at(0)
	var r: Rect2 = row.get_global_rect()
	var pos := Vector2(r.position.x + 60.0, r.position.y + 20.0)
	_motion(pos)
	_mouse(pos, true)
	_mouse(pos, false)
	assert_bool(row.is_tooltip_visible()).is_true()
	_mouse(pos, true)
	_mouse(pos, false)
	assert_bool(row.is_tooltip_visible()).is_false()
