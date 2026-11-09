class_name TestColdOpen
extends GdUnitTestSuite
## The COLD_OPEN screen and its flow (M4-26): NEW GAME on a fresh profile goes TITLE -> frame bay -> COLD_OPEN -> run 1,
## CONTINUE never shows it, back and a tap skip it, the beat is marked done, reduce motion shows everything at once.

const S := AppFlow.Screen
const E := AppFlow.Event

var _fs: MemorySaveFs
var _old_saves: SaveService
var _old_controller: RunController
var _old_problem: SaveService.Problem
var _old_pending: Variant


func before_test() -> void:
	SaveKey.reset()
	_old_saves = Game.saves
	_old_controller = Game.controller
	_old_problem = Game.save_problem
	_old_pending = Game.get("_pending_resume")
	_fs = MemorySaveFs.new()
	Game.controller = RunController.new()
	Game.controller.last_run_path = "user://runs/test_cold_open.json"
	Game.set("_pending_resume", null)
	Game.notice = ""
	var s := SaveService.new(_fs, FakeClock.new(1000), "dev")
	@warning_ignore("return_value_discarded")
	s.load_profile()
	s.attach(Game.controller)
	Game.saves = s
	Game.save_problem = s.problem


func after_test() -> void:
	Game.saves = _old_saves
	Game.controller = _old_controller
	Game.save_problem = _old_problem
	Game.set("_pending_resume", _old_pending)
	Game.notice = ""


func _flow(at: AppFlow.Screen, opener: AppFlow.Screen = S.HOME) -> AppFlow:
	var f := AppFlow.new()
	f.foundry_unlocked = true
	f.enter(opener)
	f.enter(at)
	return f


func _booted() -> ScreenRouter:
	var main: Control = (load("res://src/ui/main.tscn") as PackedScene).instantiate()
	main.size = Vector2(1080.0, 2400.0)
	add_child(main)
	auto_free(main)
	for c: Node in main.get_children():
		if c is ScreenRouter:
			var r: ScreenRouter = c
			r.quits_tree = false
			return r
	fail("no router in main")
	return null


func _to_cold_open(r: ScreenRouter) -> ColdOpen:
	assert_int(r.current_screen()).is_equal(S.TITLE)
	(r.active_screen() as TitleScreen).new_game_pressed.emit()
	assert_int(r.current_screen()).is_equal(S.FRAME_BAY)
	(r.active_screen() as FrameBay).confirmed.emit()
	assert_int(r.current_screen()).is_equal(S.COLD_OPEN)
	return r.active_screen() as ColdOpen


func test_flow_rows_for_the_cold_open() -> void:
	var f: AppFlow = _flow(S.FRAME_BAY, S.TITLE)
	f.cold_open_pending = true
	assert_int(f.apply(E.FRAME_CONFIRMED)).is_equal(S.COLD_OPEN)
	assert_bool(AppFlow.is_menu(S.COLD_OPEN)).is_true()
	assert_int(f.apply(E.COLD_OPEN_DONE)).is_equal(S.BATTLE)
	var plain: AppFlow = _flow(S.FRAME_BAY, S.TITLE)  # not pending: HOME as before
	assert_int(plain.apply(E.FRAME_CONFIRMED)).is_equal(S.HOME)


func test_a_bay_opened_from_home_never_shows_the_cold_open() -> void:
	var f: AppFlow = _flow(S.FRAME_BAY, S.HOME)
	f.cold_open_pending = true
	assert_int(f.apply(E.FRAME_CONFIRMED)).is_equal(S.HOME)
	var title: AppFlow = _flow(S.TITLE)
	title.cold_open_pending = true
	assert_int(title.apply(E.CONTINUE)).is_equal(S.HOME)  # CONTINUE skips it
	assert_int(title.apply(E.COLD_OPEN_DONE)).is_equal(AppFlow.NONE)
	assert_int(_flow(S.HOME).apply(E.COLD_OPEN_DONE)).is_equal(AppFlow.NONE)


func test_back_policy_for_the_cold_open_is_go_back() -> void:
	assert_int(BackPolicy.decide_screen(S.COLD_OPEN, false, false, false, false, false)).is_equal(
		BackPolicy.Action.GO_BACK
	)


func test_new_game_on_a_fresh_profile_goes_title_bay_cold_open_run_1() -> void:
	var r: ScreenRouter = _booted()
	var cold: ColdOpen = _to_cold_open(r)
	assert_str(cold.line_text(0)).is_equal("RELAY 06 ONLINE")
	assert_str(cold.line_text(1)).is_equal("HOSTILE SWARM DETECTED")
	assert_str(cold.line_text(2)).is_equal("HOLD THE RELAY")
	cold.skip()
	assert_int(r.current_screen()).is_equal(S.BATTLE)
	assert_int(Game.controller.state).is_equal(RunController.State.IN_RUN)
	assert_int(Game.controller.run_id).is_equal(1)


func test_continue_on_an_existing_profile_never_shows_it() -> void:
	@warning_ignore("return_value_discarded")
	Game.saves.bank_run(RunSummary.make(1, 9, BigNum.parse("250"), 1800))
	assert_bool(Game.saves.save_now()).is_true()
	var r: ScreenRouter = _booted()
	assert_int(r.current_screen()).is_equal(S.TITLE)
	(r.active_screen() as TitleScreen).continue_pressed.emit()
	assert_int(r.current_screen()).is_equal(S.HOME)
	assert_bool(r.flow.cold_open_pending).is_false()


func test_new_game_with_progress_resets_and_then_shows_the_cold_open() -> void:
	@warning_ignore("return_value_discarded")
	Game.saves.bank_run(RunSummary.make(1, 9, BigNum.parse("250"), 1800))
	assert_bool(Game.saves.save_now()).is_true()
	var r: ScreenRouter = _booted()
	(r.active_screen() as TitleScreen).new_game_pressed.emit()
	assert_bool(r.dialog().is_open()).is_true()
	r.dialog().yes_button().pressed.emit()
	(r.active_screen() as FrameBay).confirmed.emit()
	assert_int(r.current_screen()).is_equal(S.COLD_OPEN)


func test_back_skips_the_cold_open_and_starts_run_1() -> void:
	var r: ScreenRouter = _booted()
	var cold: ColdOpen = _to_cold_open(r)
	assert_int(r.handle_back(false)).is_equal(BackPolicy.Action.GO_BACK)
	assert_bool(cold.is_done()).is_true()
	assert_int(r.current_screen()).is_equal(S.BATTLE)


func test_a_tap_skips_once_and_marks_the_beat_done_in_the_profile() -> void:
	var r: ScreenRouter = _booted()
	var cold: ColdOpen = _to_cold_open(r)
	var hits: Array[int] = [0]
	cold.finished.connect(func() -> void: hits[0] += 1)
	var tap := InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	cold._gui_input(tap)
	cold.skip()
	assert_int(hits[0]).is_equal(1)
	var st: FtueState = FtueState.load_from(FtueScript.load_default(), Game.profile())
	assert_bool(st.is_done("cold_open")).is_true()
	assert_bool(st.cold_open_due()).is_false()


func test_timing_and_reduce_motion() -> void:
	assert_float(ColdOpenModel.line_alpha(0, 0.0, false)).is_equal(0.0)
	assert_float(ColdOpenModel.line_alpha(2, 2.0, false)).is_equal(0.0)  # the third line starts later
	assert_float(ColdOpenModel.line_alpha(0, 2.0, false)).is_equal(1.0)
	assert_float(ColdOpenModel.cinder_alpha(ColdOpenModel.CINDER_START_S, false)).is_equal(0.0)
	assert_float(ColdOpenModel.cinder_alpha(ColdOpenModel.TOTAL_S, false)).is_equal(1.0)
	assert_float(ColdOpenModel.line_alpha(2, 0.0, true)).is_equal(1.0)
	assert_float(ColdOpenModel.total_s(true)).is_less(ColdOpenModel.total_s(false))
	var r: ScreenRouter = _booted()
	var cold: ColdOpen = _to_cold_open(r)
	cold.reduce_motion = true
	cold.enter()
	assert_float(cold.line_alpha(2)).is_equal(1.0)
	assert_float(cold.cinder_alpha()).is_equal(1.0)
	cold.advance(ColdOpenModel.REDUCED_TOTAL_S + 0.1)
	assert_bool(cold.is_done()).is_true()
	assert_int(r.current_screen()).is_equal(S.BATTLE)


func test_the_animation_fades_in_and_ends_by_itself() -> void:
	var r: ScreenRouter = _booted()
	var cold: ColdOpen = _to_cold_open(r)
	cold.reduce_motion = false
	cold.enter()
	assert_float(cold.line_alpha(0)).is_equal(0.0)
	cold.advance(1.2)
	assert_float(cold.line_alpha(0)).is_greater(0.5)
	assert_float(cold.line_alpha(2)).is_equal(0.0)
	cold.advance(ColdOpenModel.TOTAL_S)
	assert_bool(cold.is_done()).is_true()
	assert_int(r.current_screen()).is_equal(S.BATTLE)
