class_name TestDebugOverlayGate
extends GdUnitTestSuite
## B1-07-A: the debug overlay must not open by touch in a release build (gestures_enabled is false there).

const SCENE: String = "res://src/ui/debug_overlay.tscn"


func _make(enabled: bool) -> DebugOverlay:
	var overlay: DebugOverlay = (load(SCENE) as PackedScene).instantiate() as DebugOverlay
	overlay.gestures_enabled = enabled
	add_child(overlay)
	auto_free(overlay)
	overlay.hide()
	return overlay


func _double_tap(o: DebugOverlay) -> void:
	o._on_press(Vector2(40, 40), 1000)
	o._on_release(1050)
	o._on_press(Vector2(40, 40), 1200)
	o._on_release(1250)


func _long_press(o: DebugOverlay) -> void:
	o._on_press(Vector2(40, 40), 5000)
	o._on_release(5000 + DebugOverlay.LONG_PRESS_MS + 100)


func test_disabled_double_tap_stays_hidden() -> void:
	var o: DebugOverlay = _make(false)
	_double_tap(o)
	assert_bool(o.is_shown()).is_false()


func test_disabled_long_press_stays_hidden() -> void:
	var o: DebugOverlay = _make(false)
	_long_press(o)
	assert_bool(o.is_shown()).is_false()


func test_disabled_input_event_stays_hidden() -> void:
	var o: DebugOverlay = _make(false)
	for t: int in 2:
		var e := InputEventScreenTouch.new()
		e.position = Vector2(40, 40)
		e.pressed = true
		o._input(e)
		e = InputEventScreenTouch.new()
		e.position = Vector2(40, 40)
		e.pressed = false
		o._input(e)
	assert_bool(o.is_shown()).is_false()


func test_disabled_toggle_stays_hidden() -> void:
	var o: DebugOverlay = _make(false)
	o.toggle()
	assert_bool(o.is_shown()).is_false()


func test_hide_and_visible_still_work_when_disabled() -> void:
	var o: DebugOverlay = _make(false)
	o.show()
	assert_bool(o.is_shown()).is_true()
	o.hide()
	assert_bool(o.is_shown()).is_false()


func test_enabled_double_tap_toggles() -> void:
	var o: DebugOverlay = _make(true)
	_double_tap(o)
	assert_bool(o.is_shown()).is_true()


func test_enabled_long_press_toggles() -> void:
	var o: DebugOverlay = _make(true)
	_long_press(o)
	assert_bool(o.is_shown()).is_true()
