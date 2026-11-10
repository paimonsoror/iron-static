class_name TestDraftOverlay
extends GdUnitTestSuite
## DraftOverlay (M4-16): opens for an open draft, a completed tap picks (once, between frames) and closes, swipes and
## stale presses do nothing, the sim does not step behind it, back opens the pause menu over it.


class FlushSpy:
	extends SaveService
	var flushes: int = 0

	func flush_for_background() -> void:
		flushes += 1


var _c: RunController
var _overlay: DraftOverlay
var _hud: Hud
var _shell: MobileShell
var _spy: SpyAudioDirector


func before_test() -> void:
	_spy = auto_free(SpyAudioDirector.new())
	AudioHooks.override = _spy
	_c = DraftTestWorld.controller_with_draft(["patch_overcharge", "patch_plating", "patch_t_greed"])
	var root: Control = auto_free(Control.new())
	root.size = Vector2(1080.0, 2400.0)
	add_child(root)
	_hud = (load("res://src/ui/hud.tscn") as PackedScene).instantiate()
	root.add_child(_hud)
	_overlay = (load("res://src/ui/draft/draft_overlay.tscn") as PackedScene).instantiate()
	_overlay.reduce_motion = true
	root.add_child(_overlay)
	var results := Control.new()
	results.visible = false
	root.add_child(results)
	var debug := Control.new()
	debug.visible = false
	root.add_child(debug)
	_shell = MobileShell.new()
	_shell.quits_tree = false
	root.add_child(_shell)
	_shell.setup(_c, _hud, results, debug)


func after_test() -> void:
	AudioHooks.override = null


func _mouse(pressed: bool, at: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	return e


func _touch(pressed: bool, at: Vector2, canceled: bool = false) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.pressed = pressed
	e.position = at
	e.canceled = canceled
	return e


func _tap(i: int) -> void:
	var card: DraftCard = _overlay.card(i)
	var at: Vector2 = card.size * 0.5
	card._gui_input(_mouse(true, at))
	card._gui_input(_mouse(false, at + Vector2(8.0, 4.0)))


func _open() -> void:
	_overlay.open(_c.world)
	await get_tree().process_frame
	await get_tree().process_frame


func test_open_shows_three_cards_with_the_gamble_flagged() -> void:
	await _open()
	assert_bool(_overlay.is_open()).is_true()
	assert_bool(_overlay.visible).is_true()
	assert_str(_overlay.card(0).texts()[0]).is_equal("OVERCHARGE")
	assert_str(_overlay.card(2).texts()[2]).starts_with("COST: HULL INTEGRITY ")
	for i: int in 3:
		assert_float(_overlay.card(i).size.y).is_greater_equal(148.0)
	assert_array(_spy.sfx).contains_exactly(["sfx_draft_open"])


func test_tapping_card_2_picks_slot_2_once_and_closes() -> void:
	await _open()
	var picks: Array[int] = []
	_overlay.picked.connect(func(slot: int) -> void: picks.append(slot))
	_tap(2)
	_tap(2)  # the overlay is closed: a second tap does nothing
	assert_array(picks).contains_exactly([2])
	assert_bool(_overlay.is_open()).is_false()
	assert_bool(_c.world.is_draft_open()).is_false()
	assert_int(_c.world.input_log.size()).is_equal(1)
	assert_int(_c.world.input_log.kinds[0]).is_equal(InputLog.CMD_PICK)
	assert_int(_c.world.input_log.arg_a[0]).is_equal(2)
	assert_int(_c.world.patches.total_picks).is_equal(1)
	assert_array(_spy.sfx).contains_exactly(["sfx_draft_open", "sfx_draft_pick"])


func test_swipe_cancel_and_stale_press_do_not_pick() -> void:
	await _open()
	var card: DraftCard = _overlay.card(0)
	var at: Vector2 = card.size * 0.5
	card._gui_input(_touch(true, at))
	card._gui_input(_touch(false, at + Vector2(300.0, 0.0)))  # travelled: a swipe
	card._gui_input(_touch(true, at))
	card._gui_input(_touch(false, at, true))  # cancelled by the system (back swipe)
	card._gui_input(_touch(false, at))  # release with no press seen
	assert_bool(_overlay.is_open()).is_true()
	card._gui_input(_touch(true, at))
	_overlay.close()  # a press from before the overlay (re)opened
	await _open()
	card._gui_input(_touch(false, at))
	assert_bool(_c.world.is_draft_open()).is_true()
	assert_int(_c.world.input_log.size()).is_equal(0)


func test_touch_and_its_emulated_mouse_pick_once() -> void:
	await _open()
	var picks: Array[int] = []
	_overlay.picked.connect(func(slot: int) -> void: picks.append(slot))
	var card: DraftCard = _overlay.card(1)
	var at: Vector2 = card.size * 0.5
	card._gui_input(_touch(true, at))
	card._gui_input(_mouse(true, at))
	card._gui_input(_touch(false, at))
	card._gui_input(_mouse(false, at))
	assert_array(picks).contains_exactly([1])


func test_the_sim_does_not_advance_while_the_draft_is_open() -> void:
	await _open()
	var tick: int = _c.world.tick
	var hash_before: String = _c.world.state_hash()
	for i: int in 60:
		@warning_ignore("return_value_discarded")
		_c.update(1.0 / 30.0)
	assert_int(_c.world.tick).is_equal(tick)
	assert_str(_c.world.state_hash()).is_equal(hash_before)
	assert_bool(_overlay.is_open()).is_true()


func test_back_opens_the_pause_menu_over_the_draft_and_resume_returns() -> void:
	await _open()
	assert_int(_shell.handle_back()).is_equal(BackPolicy.Action.PAUSE)
	assert_bool(_shell.overlay().visible).is_true()
	assert_bool(_c.world.is_draft_open()).is_true()
	assert_bool(_overlay.is_open()).is_true()
	assert_int(_shell.handle_back()).is_equal(BackPolicy.Action.RESUME)
	assert_bool(_shell.overlay().visible).is_false()
	assert_bool(_c.world.is_draft_open()).is_true()
	assert_bool(_overlay.is_open()).is_true()
	assert_int(_shell.exit_count).is_equal(0)


func test_exit_game_saves_with_the_draft_open_and_background_keeps_it() -> void:
	await _open()
	var spy := FlushSpy.new(MemorySaveFs.new(), FakeClock.new(), "dev")
	_shell.saves = spy
	_shell.lifecycle_enabled = true
	_shell.on_app_suspended()  # backgrounded during the draft: the pause menu opens over it
	assert_bool(_c.paused).is_true()
	assert_bool(_c.world.is_draft_open()).is_true()
	_shell.exit_game()
	assert_int(spy.flushes).is_equal(1)
	assert_int(_shell.exit_count).is_equal(1)
	assert_bool(_c.world.is_draft_open()).is_true()


func test_tapping_the_dim_does_nothing() -> void:
	await _open()
	_overlay._gui_input(_mouse(true, Vector2(5.0, 5.0)))
	_overlay._gui_input(_mouse(false, Vector2(5.0, 5.0)))
	assert_bool(_overlay.is_open()).is_true()
	assert_bool(_c.world.is_draft_open()).is_true()


func test_open_without_a_draft_is_a_no_op_and_close_hides() -> void:
	var idle := RunController.new()
	idle.last_run_path = "user://runs/test_draft_ui.json"
	@warning_ignore("return_value_discarded")
	idle.start_run(3)
	_overlay.open(idle.world)
	assert_bool(_overlay.is_open()).is_false()
	await _open()
	_overlay.close()
	assert_bool(_overlay.visible).is_false()
	assert_bool(_c.world.is_draft_open()).is_true()


func test_reroll_button_rerolls_once_logs_it_and_shows_it_used() -> void:
	await _open()
	var button: Button = _overlay.reroll_button()
	assert_bool(button.disabled).is_false()
	assert_str(button.text).is_equal("REROLL ALL")
	assert_float(button.size.y).is_greater_equal(148.0)
	button.pressed.emit()
	assert_int(_c.world.input_log.size()).is_equal(1)
	assert_int(_c.world.input_log.kinds[0]).is_equal(InputLog.CMD_REROLL)
	assert_int(_c.world.draft.rerolls_used).is_equal(1)
	assert_bool(_overlay.is_open()).is_true()
	assert_bool(button.disabled).is_true()
	assert_str(button.text).is_equal("REROLLED")
	button.pressed.emit()  # used: nothing more is logged
	assert_int(_c.world.input_log.size()).is_equal(1)
	for i: int in 3:  # the cards now show the new offers
		var idx: int = _c.world.draft.offers[i]
		assert_str(_overlay.card(i).texts()[0]).is_equal(Strings.get_text(_c.world.config.patches[idx].name_key))
