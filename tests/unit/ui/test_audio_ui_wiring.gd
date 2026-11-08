class_name TestAudioUiWiring
extends GdUnitTestSuite
## A1-06 and A1-07 hooks on the real UI scripts, with a spy director: hold-to-buy (step, end, deny), tabs, speed and
## pause buttons, results button, pause overlay and the lifecycle pause_all / resume_all calls.

var _spy: SpyAudioDirector
var _vp: SubViewport = null


func before_test() -> void:
	_spy = auto_free(SpyAudioDirector.new())
	AudioHooks.override = _spy


func after_test() -> void:
	AudioHooks.override = null


func _panel(scrap: float = 1.0e9) -> UpgradePanel:
	_vp = auto_free(SubViewport.new())
	_vp.size = Vector2i(1080, 1000)
	add_child(_vp)
	var panel: UpgradePanel = (load("res://src/ui/upgrade_panel.tscn") as PackedScene).instantiate()
	_vp.add_child(panel)
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.best_wave_s1 = 99
	var w := SimWorld.new(cfg)
	w.economy.scrap = BigNum.from_float(scrap)
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


func _hud() -> Hud:
	var root: Control = auto_free(Control.new())
	root.size = Vector2(1080.0, 1920.0)
	add_child(root)
	var hud: Hud = (load("res://src/ui/hud.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	return hud


func test_tap_buy_plays_one_step_and_resets_the_streak() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(100)
	var pos: Vector2 = _center(panel.row_at(0).get_node("%BuyButton") as Control)
	_motion(pos)
	_mouse(pos, true)
	_mouse(pos, false)
	assert_int(_spy.buy_steps).is_equal(1)
	assert_int(_spy.buy_ends).is_equal(1)
	assert_str(_spy.log[0]).is_equal("buy_end")  # release ends the (empty) streak before the tap's own step
	assert_int(_spy.count("sfx_ui_deny")).is_equal(0)


func test_hold_plays_a_step_per_repeat_and_ends_on_release() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(100)
	var row: UpgradeRow = panel.row_at(0)
	var pos: Vector2 = _center(row.get_node("%BuyButton") as Control)
	_motion(pos)
	_mouse(pos, true)
	row.advance_hold(0.4)
	row.advance_hold(1.0)
	assert_int(_spy.buy_steps).is_greater(3)
	assert_int(_spy.buy_ends).is_equal(0)
	_mouse(pos, false)
	assert_int(_spy.buy_ends).is_equal(1)
	assert_str(_spy.log[_spy.log.size() - 1]).is_equal("buy_end")


func test_drag_cancel_ends_the_streak() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(100)
	var row: UpgradeRow = panel.row_at(0)
	var pos: Vector2 = _center(row.get_node("%BuyButton") as Control)
	_motion(pos)
	_mouse(pos, true)
	row.advance_hold(0.4)
	_motion(pos + Vector2(0, 60))
	assert_int(_spy.buy_ends).is_equal(1)


func test_unaffordable_press_denies_and_does_not_play_a_buy_step() -> void:
	var panel: UpgradePanel = _panel(0.0)
	await await_millis(100)
	var pos: Vector2 = _center(panel.row_at(0).get_node("%BuyButton") as Control)
	_motion(pos)
	_mouse(pos, true)
	_mouse(pos, false)
	assert_int(_spy.count("sfx_ui_deny")).is_equal(1)
	assert_int(_spy.buy_steps).is_equal(0)


func test_hold_that_runs_out_of_scrap_denies_once_and_stops() -> void:
	var panel: UpgradePanel = _panel()
	await await_millis(100)
	var row: UpgradeRow = panel.row_at(0)
	var pos: Vector2 = _center(row.get_node("%BuyButton") as Control)
	_motion(pos)
	_mouse(pos, true)
	row.advance_hold(0.4)
	panel.bound_world().economy.scrap = BigNum.zero()
	panel.refresh()
	row.advance_hold(1.0)
	assert_int(_spy.count("sfx_ui_deny")).is_equal(1)
	assert_int(_spy.buy_ends).is_equal(1)


func test_tabs_play_a_tap() -> void:
	var panel: UpgradePanel = _panel()
	var tab: Button = panel.find_child("Tab_" + UpgradePanelModel.TAB_IDS[1], true, false) as Button
	tab.pressed.emit()
	assert_int(_spy.count("sfx_ui_tap")).is_equal(1)


func test_speed_button_taps() -> void:
	var hud: Hud = _hud()
	(hud.find_child("SpeedButton", true, false) as Button).pressed.emit()
	assert_array(_spy.log).contains_exactly(["sfx_ui_tap"])


func test_hud_pause_pauses_audio_around_the_tap_and_resume_thaws_first() -> void:
	var hud: Hud = _hud()
	var button: Button = hud.find_child("PauseButton", true, false) as Button
	button.pressed.emit()
	assert_array(_spy.log).contains_exactly(["sfx_ui_tap", "pause"])
	button.pressed.emit()
	assert_array(_spy.log).contains_exactly(["sfx_ui_tap", "pause", "resume", "sfx_ui_tap"])


func test_results_button_taps_and_still_redeploys() -> void:
	var results: ResultsOverlay = (load("res://src/ui/results_overlay.tscn") as PackedScene).instantiate()
	add_child(results)
	auto_free(results)
	var fired: Array[bool] = []
	results.redeploy_pressed.connect(func() -> void: fired.append(true))
	(results.find_child("RedeployButton", true, false) as Button).pressed.emit()
	assert_int(_spy.count("sfx_ui_tap")).is_equal(1)
	assert_int(fired.size()).is_equal(1)


func test_shell_pause_and_resume_call_the_director() -> void:
	var c := RunController.new()
	c.last_run_path = "user://runs/test_audio_ui_wiring.json"
	@warning_ignore("return_value_discarded")
	c.start_run(3)
	var hud: Hud = _hud()
	var results := Control.new()
	results.visible = false
	var debug := Control.new()
	debug.visible = false
	add_child(results)
	auto_free(results)
	add_child(debug)
	auto_free(debug)
	var shell := MobileShell.new()
	add_child(shell)
	auto_free(shell)
	shell.setup(c, hud, results, debug)
	shell.lifecycle_enabled = true
	shell.on_app_suspended()
	assert_int(_spy.pauses).is_equal(1)
	assert_bool(c.paused).is_true()
	shell.resume()
	assert_int(_spy.resumes).is_equal(1)
	assert_str(_spy.log[_spy.log.size() - 1]).is_equal("sfx_ui_tap")  # the tap sounds after the thaw
	assert_bool(c.paused).is_false()
