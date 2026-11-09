class_name TestPauseMenu
extends GdUnitTestSuite
## Pause menu (RESUME / ABORT MISSION / EXIT GAME): completed-tap buttons, the back-swipe protection, the abort confirm.


class FlushSpy:
	extends SaveService
	var flushes: int = 0

	func flush_for_background() -> void:
		flushes += 1


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


## Opens the menu and waits for the layout; returns the buttons control.
func _open_menu() -> PauseButtons:
	_shell.pause()
	await await_idle_frame()
	return _shell.overlay().buttons()


func _row_center(b: PauseButtons, i: int) -> Vector2:
	return b.row_rect(i).get_center()


func test_resume_button_tap_resumes() -> void:
	var b: PauseButtons = await _open_menu()
	var at: Vector2 = _row_center(b, 0)
	b._gui_input(_mouse(true, at))
	assert_bool(_c.paused).is_true()  # the press alone never resumes
	b._gui_input(_mouse(false, at + Vector2(10.0, 5.0)))
	assert_bool(_c.paused).is_false()
	assert_bool(_shell.overlay().visible).is_false()


func test_tap_outside_the_buttons_does_nothing() -> void:
	var b: PauseButtons = await _open_menu()
	var gap: Vector2 = Vector2(b.size.x * 0.5, PauseButtons.ROW_H + PauseButtons.ROW_GAP * 0.5)
	assert_int(b.row_at(gap)).is_equal(-1)
	b._gui_input(_mouse(true, gap))
	b._gui_input(_mouse(false, gap))
	_shell.overlay()._gui_input(_mouse(true, Vector2(5.0, 5.0)))
	_shell.overlay()._gui_input(_mouse(false, Vector2(5.0, 5.0)))
	assert_bool(_c.paused).is_true()
	assert_bool(_shell.overlay().visible).is_true()
	assert_bool(_shell.overlay().confirm_open()).is_false()


## Phone bug: the gesture-navigation back swipe delivers a touch press, then Android cancels the touch. That must
## not activate any button (so the next back still reaches BackPolicy with the menu open).
func test_back_swipe_press_then_cancel_activates_nothing() -> void:
	var b: PauseButtons = await _open_menu()
	for i: int in 3:
		var at: Vector2 = _row_center(b, i)
		b._gui_input(_touch(true, at))
		var up := _touch(false, at + Vector2(30.0, 0.0))
		up.canceled = true
		b._gui_input(up)
	assert_bool(_c.paused).is_true()
	assert_bool(_shell.overlay().confirm_open()).is_false()
	assert_int(_shell.exit_count).is_equal(0)
	assert_int(_shell.handle_back()).is_equal(BackPolicy.Action.RESUME)


func test_swipe_without_cancel_and_release_without_press_do_not_act() -> void:
	var b: PauseButtons = await _open_menu()
	var at: Vector2 = _row_center(b, 0)
	b._gui_input(_touch(true, at))
	b._gui_input(_touch(false, at + Vector2(300.0, 0.0)))  # travelled far: a swipe, not a tap
	assert_bool(_c.paused).is_true()
	b._gui_input(_touch(false, at))  # stray release, no press seen
	assert_bool(_c.paused).is_true()
	b._gui_input(_touch(true, _row_center(b, 0)))  # pressed on RESUME, released on EXIT: nothing
	b._gui_input(_touch(false, _row_center(b, 2)))
	assert_bool(_c.paused).is_true()
	assert_int(_shell.exit_count).is_equal(0)


func test_touch_and_its_emulated_mouse_act_once() -> void:
	var resumes: Array[int] = [0]
	_shell.overlay().resume_requested.connect(func() -> void: resumes[0] += 1)
	var b: PauseButtons = await _open_menu()
	var at: Vector2 = _row_center(b, 0)
	b._gui_input(_touch(true, at))
	b._gui_input(_mouse(true, at))
	b._gui_input(_touch(false, at))
	b._gui_input(_mouse(false, at))
	assert_int(resumes[0]).is_equal(1)


func test_a_press_from_before_the_menu_never_acts() -> void:
	var b: PauseButtons = await _open_menu()
	_shell.resume()
	b._gui_input(_touch(true, _row_center(b, 0)))  # menu hidden: e.g. the swipe that opened it
	_shell.pause()
	b._gui_input(_touch(false, _row_center(b, 0)))
	assert_bool(_c.paused).is_true()


func test_abort_button_opens_the_confirm_and_back_closes_only_the_confirm() -> void:
	var b: PauseButtons = await _open_menu()
	var at: Vector2 = _row_center(b, 1)
	b._gui_input(_mouse(true, at))
	b._gui_input(_mouse(false, at))
	var o: PauseOverlay = _shell.overlay()
	assert_bool(o.confirm_open()).is_true()
	assert_str(o.confirm().title_text()).is_equal(Strings.get_text("pause.abort_title"))
	assert_str(o.confirm().yes_button().text).is_equal(Strings.get_text("pause.abort_yes"))
	assert_str(o.confirm().no_button().text).is_equal(Strings.get_text("pause.abort_no"))
	assert_int(_shell.handle_back()).is_equal(BackPolicy.Action.CLOSE_DIALOG)
	assert_bool(o.confirm_open()).is_false()
	assert_bool(o.visible).is_true()  # the menu stays
	assert_bool(_c.state == RunController.State.IN_RUN).is_true()
	assert_int(_shell.handle_back()).is_equal(BackPolicy.Action.RESUME)


func test_exit_button_flushes_the_run_and_quits() -> void:
	_shell.quits_tree = false
	var spy := FlushSpy.new(MemorySaveFs.new(), FakeClock.new(), "dev")
	_shell.saves = spy
	var b: PauseButtons = await _open_menu()
	var at: Vector2 = _row_center(b, 2)
	b._gui_input(_mouse(true, at))
	b._gui_input(_mouse(false, at))
	assert_int(_shell.exit_count).is_equal(1)
	assert_int(spy.flushes).is_equal(1)


func _touch(pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var ev := InputEventScreenTouch.new()
	ev.pressed = pressed
	ev.position = pos
	return ev


func _mouse(pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.pressed = pressed
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = pos
	return ev


func test_confirmed_abort_banks_goes_home_and_shows_the_toast() -> void:
	var router := ScreenRouter.new()
	router.quits_tree = false
	_shell.get_parent().add_child(router)
	var battle: Node2D = auto_free(Node2D.new())
	router.setup(_c, battle, _hud, _results)
	_shell.set_router(router)
	router.show_battle()
	var runs_before: int = Game.profile().runs_total
	@warning_ignore("return_value_discarded")
	_c.fast_forward(60)
	var b: PauseButtons = await _open_menu()
	var at: Vector2 = _row_center(b, 1)
	b._gui_input(_mouse(true, at))
	b._gui_input(_mouse(false, at))
	var aborted: Array[int] = [0]
	_c.run_aborted.connect(func(_w: SimWorld) -> void: aborted[0] += 1)
	_shell.overlay().confirm().yes_button().pressed.emit()
	assert_int(aborted[0]).is_equal(1)
	assert_int(router.current_screen()).is_equal(AppFlow.Screen.HOME)
	assert_bool(_shell.overlay().visible).is_false()
	assert_bool(_c.paused).is_false()
	assert_bool(_hud.is_paused()).is_false()
	assert_bool(router.toast_visible()).is_true()
	assert_str(router.toast_text()).starts_with("MISSION ABORTED: +")
	assert_str(router.toast_text()).ends_with(" DATA")
	assert_int(_c.state).is_equal(RunController.State.RESULTS)
	assert_int(Game.profile().runs_total).is_equal(runs_before)  # this bare controller is not Game's: nothing banked there


func test_abort_toast_text_formats_the_earned_data() -> void:
	assert_str(AbortMission.toast_text(BigNum.from_int(1234))).is_equal("MISSION ABORTED: +1.23K DATA")
	assert_str(AbortMission.toast_text(BigNum.zero())).is_equal("MISSION ABORTED: +0 DATA")
