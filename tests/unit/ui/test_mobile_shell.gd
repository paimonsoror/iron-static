class_name TestMobileShell
extends GdUnitTestSuite
## MobileShell (V1-24): back gesture actions, lifecycle pause (no ticks, no state change) and HUD safe margins.

var _c: RunController
var _hud: Hud
var _results: Control
var _debug: Control
var _shell: MobileShell


func before_test() -> void:
	_c = RunController.new()
	_c.last_run_path = "user://runs/test_mobile_shell.json"
	@warning_ignore("return_value_discarded")
	_c.start_run(3)
	var root: Control = auto_free(Control.new())
	root.size = Vector2(1080.0, 1920.0)
	add_child(root)
	_hud = (load("res://src/ui/hud.tscn") as PackedScene).instantiate()
	root.add_child(_hud)
	_results = Control.new()
	_results.visible = false
	root.add_child(_results)
	_debug = Control.new()
	_debug.visible = false
	root.add_child(_debug)
	_shell = MobileShell.new()
	root.add_child(_shell)
	_shell.setup(_c, _hud, _results, _debug)
	_shell.lifecycle_enabled = true


func test_back_pauses_then_would_quit() -> void:
	assert_int(_shell.handle_back()).is_equal(BackPolicy.Action.PAUSE)
	assert_bool(_c.paused).is_true()
	assert_bool(_shell.overlay().visible).is_true()
	assert_bool(_hud.is_paused()).is_true()
	# A second back quits; check the decision only (quitting the test runner is not an option).
	assert_int(BackPolicy.decide(false, _c.paused, _shell.in_battle())).is_equal(BackPolicy.Action.QUIT)


func test_back_closes_the_open_panel_first() -> void:
	_debug.visible = true
	assert_int(_shell.handle_back()).is_equal(BackPolicy.Action.CLOSE_PANEL)
	assert_bool(_debug.visible).is_false()
	assert_bool(_c.paused).is_false()


func test_resume_hides_overlay_and_unpauses() -> void:
	_shell.pause()
	_shell.resume()
	assert_bool(_c.paused).is_false()
	assert_bool(_shell.overlay().visible).is_false()
	assert_bool(_hud.is_paused()).is_false()


func test_app_suspend_pauses_without_touching_sim_state() -> void:
	@warning_ignore("return_value_discarded")
	_c.fast_forward(90)
	var before: String = _c.world.state_hash()
	var tick: int = _c.world.tick
	_shell.on_app_suspended()
	assert_bool(_c.paused).is_true()
	assert_bool(_shell.overlay().visible).is_true()
	for i: int in 30:
		assert_int(_c.update(1.0 / 30.0)).is_equal(0)
	assert_int(_c.world.tick).is_equal(tick)
	assert_str(_c.world.state_hash()).is_equal(before)


func test_suspend_ignored_when_disabled_or_run_over() -> void:
	_shell.lifecycle_enabled = false
	_shell.on_app_suspended()
	assert_bool(_c.paused).is_false()
	_shell.lifecycle_enabled = true
	_results.visible = true
	_shell.on_app_suspended()
	assert_bool(_c.paused).is_false()


func test_overlay_tap_resumes() -> void:
	_shell.pause()
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	_shell.overlay()._gui_input(ev)
	assert_bool(_c.paused).is_false()
	assert_bool(_shell.overlay().visible).is_false()


func test_overlay_texts_come_from_strings() -> void:
	var before: int = Strings.missing_count
	var o := PauseOverlay.new()
	add_child(o)
	auto_free(o)
	assert_int(Strings.missing_count).is_equal(before)
	for k: String in ["pause.title", "pause.resume_hint", "pause.exit_hint"]:
		assert_bool(Strings.has_key(k)).is_true()


func test_hud_safe_margins_move_top_bar_and_bottom_panel_and_reset() -> void:
	var top_bar: Control = _hud.get_node("%TopBar")
	var panel: Control = _hud.upgrade_panel()
	_hud.apply_safe_margins(Vector4(10.0, 130.0, 20.0, 48.0))
	assert_float(top_bar.offset_top).is_equal(130.0)
	assert_float(top_bar.offset_left).is_equal(10.0)
	assert_float(top_bar.offset_right).is_equal(-20.0)
	assert_float(panel.offset_bottom).is_equal(-48.0)
	_hud.apply_safe_margins(Vector4.ZERO)
	assert_float(top_bar.offset_top).is_equal(0.0)
	assert_float(panel.offset_bottom).is_equal(0.0)


func test_desktop_refresh_leaves_margins_zero() -> void:
	_shell.safe_area_enabled = false
	_shell.refresh_safe_area()
	assert_float((_hud.get_node("%TopBar") as Control).offset_top).is_equal(0.0)


func _with_router() -> ScreenRouter:
	var router := ScreenRouter.new()
	router.quits_tree = false
	_shell.get_parent().add_child(router)
	var battle: Node2D = auto_free(Node2D.new())
	router.setup(_c, battle, _hud, _results)
	_shell.set_router(router)
	return router


func test_router_leaves_the_battle_back_behavior_unchanged() -> void:
	var router: ScreenRouter = _with_router()
	router.show_battle()
	assert_int(_shell.handle_back()).is_equal(BackPolicy.Action.PAUSE)
	assert_bool(_c.paused).is_true()
	_debug.visible = true
	_c.paused = false
	assert_int(_shell.handle_back()).is_equal(BackPolicy.Action.CLOSE_PANEL)


func test_router_screens_take_the_back_gesture_through_the_policy() -> void:
	var router: ScreenRouter = _with_router()
	router.boot()
	assert_int(router.current_screen()).is_equal(AppFlow.Screen.TITLE)
	assert_bool(router.dispatch(AppFlow.Event.CONTINUE)).is_true()
	assert_int(_shell.handle_back()).is_equal(BackPolicy.Action.ARM_EXIT)
	_debug.visible = true
	assert_int(_shell.handle_back()).is_equal(BackPolicy.Action.CLOSE_PANEL)
	assert_bool(_debug.visible).is_false()
	assert_int(_shell.handle_back()).is_equal(BackPolicy.Action.QUIT)  # second back inside the 2 s window
