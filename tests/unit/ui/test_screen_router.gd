class_name TestScreenRouter
extends GdUnitTestSuite
## ScreenRouter in the real main scene (M3-14): boot targets, DEPLOY, results, back, save problem, resume,
## battle view hiding. `Game` is the autoload; the test swaps in an in-memory SaveService and a fresh controller
## (and restores them) so nothing touches user://save.

const RUN_PATH: String = "user://runs/test_screen_router.json"
const MAX_TICKS: int = 60000

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
	Game.controller.last_run_path = RUN_PATH
	Game.set("_pending_resume", null)
	Game.notice = ""
	_use_service(SaveService.new(_fs, FakeClock.new(1000), "dev"))


func after_test() -> void:
	Game.saves = _old_saves
	Game.controller = _old_controller
	Game.save_problem = _old_problem
	Game.set("_pending_resume", _old_pending)
	Game.notice = ""


func _use_service(s: SaveService) -> void:
	@warning_ignore("return_value_discarded")
	s.load_profile()
	s.attach(Game.controller)
	Game.saves = s
	Game.save_problem = s.problem


func _main() -> Control:
	var main: Control = (load("res://src/ui/main.tscn") as PackedScene).instantiate()
	main.size = Vector2(1080.0, 2400.0)
	add_child(main)
	auto_free(main)
	return main


func _router(main: Control) -> ScreenRouter:
	for c: Node in main.get_children():
		if c is ScreenRouter:
			var r: ScreenRouter = c
			r.quits_tree = false
			return r
	fail("no router in main")
	return null


## Boots, then leaves the title through CONTINUE (always legal from TITLE) so the test starts on HOME.
func _home_router(main: Control) -> ScreenRouter:
	var r: ScreenRouter = _router(main)
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.TITLE)
	assert_bool(r.dispatch(AppFlow.Event.CONTINUE)).is_true()
	return r


func _press_home_deploy(router: ScreenRouter) -> void:
	var home: HomeScreen = router.active_screen() as HomeScreen
	assert_object(home).is_not_null()
	home.deploy_pressed.emit()


func test_fresh_profile_boots_to_title_then_continue_to_home_with_the_battle_view_off() -> void:
	var main: Control = _main()
	var r: ScreenRouter = _home_router(main)
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.HOME)
	assert_that(r.size).is_equal(main.size)  # the router and its screen fill the view
	assert_that(r.active_screen().size).is_equal(main.size)
	var battle: Node = main.get_node("%BattleView")
	var hud: Control = main.get_node("%Hud")
	assert_bool((battle as CanvasItem).visible).is_false()
	assert_bool(battle.is_processing()).is_false()
	assert_bool(hud.visible).is_false()
	assert_bool(hud.is_processing()).is_false()
	assert_bool(_visible(main, "%ResultsOverlay")).is_false()
	assert_int(Game.controller.state).is_not_equal(RunController.State.IN_RUN)  # no run before DEPLOY
	assert_bool((r.active_screen() as HomeScreen).nav_foundry.visible).is_false()


func test_profile_with_a_banked_run_shows_the_foundry_nav() -> void:
	Game.saves.profile.runs_total = 1
	var r: ScreenRouter = _home_router(_main())
	assert_bool((r.active_screen() as HomeScreen).nav_foundry.visible).is_true()


func test_deploy_runs_then_results_then_back_goes_home_and_redeploy_works() -> void:
	var main: Control = _main()
	var r: ScreenRouter = _home_router(main)
	_press_home_deploy(r)
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.BATTLE)
	assert_int(Game.controller.state).is_equal(RunController.State.IN_RUN)
	assert_bool(_visible(main, "%BattleView")).is_true()
	assert_bool(_visible(main, "%Hud")).is_true()
	assert_bool(_node(main, "%BattleView").is_processing()).is_true()
	@warning_ignore("return_value_discarded")
	Game.controller.auto_pick_draft = true  # the first draft (wave 5) would otherwise hold the run (R1-04)
	Game.controller.fast_forward(MAX_TICKS)
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.RESULTS)
	assert_bool(_visible(main, "%ResultsOverlay")).is_true()
	assert_int(r.handle_back(false)).is_equal(BackPolicy.Action.GO_HOME)
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.HOME)
	assert_bool(_visible(main, "%ResultsOverlay")).is_false()
	assert_bool((r.active_screen() as HomeScreen).nav_foundry.visible).is_true()  # runs_total is 1 now
	_press_home_deploy(r)
	assert_int(Game.controller.run_id).is_equal(2)  # a second deployment, next run id


func test_results_to_foundry_and_back_restores_results() -> void:
	var main: Control = _main()
	var r: ScreenRouter = _home_router(main)
	_press_home_deploy(r)
	@warning_ignore("return_value_discarded")
	Game.controller.auto_pick_draft = true  # the first draft (wave 5) would otherwise hold the run (R1-04)
	Game.controller.fast_forward(MAX_TICKS)
	assert_bool(r.dispatch(AppFlow.Event.OPEN_FOUNDRY)).is_true()
	assert_bool(_visible(main, "%ResultsOverlay")).is_false()
	assert_bool((r.active_screen() as FoundryScreen).intro_open()).is_true()  # FO-1: the first back closes it
	@warning_ignore("return_value_discarded")
	r.handle_back(false)
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.FOUNDRY)
	assert_int(r.handle_back(false)).is_equal(BackPolicy.Action.GO_BACK)
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.RESULTS)
	assert_bool(_visible(main, "%ResultsOverlay")).is_true()


func test_home_back_arms_then_second_back_quits() -> void:
	var r: ScreenRouter = _home_router(_main())
	assert_int(r.handle_back(false)).is_equal(BackPolicy.Action.ARM_EXIT)
	assert_bool(r.toast_visible()).is_true()
	assert_str(r.toast_text()).is_equal(Strings.get_text("exit.back_again"))
	assert_int(r.quit_requested_count).is_equal(0)
	assert_int(r.handle_back(false)).is_equal(BackPolicy.Action.QUIT)
	assert_int(r.quit_requested_count).is_equal(1)


func test_settings_back_returns_to_home() -> void:
	var r: ScreenRouter = _home_router(_main())
	assert_bool(r.dispatch(AppFlow.Event.OPEN_SETTINGS)).is_true()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.SETTINGS)
	assert_int(r.handle_back(false)).is_equal(BackPolicy.Action.GO_BACK)
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.HOME)


func test_foundry_dispatch_is_refused_before_the_first_death() -> void:
	var r: ScreenRouter = _home_router(_main())
	assert_bool(r.dispatch(AppFlow.Event.OPEN_FOUNDRY)).is_false()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.HOME)


func test_corrupt_save_boots_to_the_problem_screen_and_start_new_quarantines() -> void:
	_fs.files["profile.sav"] = PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
	_use_service(SaveService.new(_fs, FakeClock.new(1000), "dev"))
	assert_int(Game.save_problem).is_equal(SaveService.Problem.CORRUPT)
	var r: ScreenRouter = _router(_main())
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.SAVE_PROBLEM)
	assert_int(r.handle_back(false)).is_equal(BackPolicy.Action.QUIT)
	var screen: SaveProblemScreen = r.active_screen() as SaveProblemScreen
	assert_bool(_start_button(screen).visible).is_true()  # START NEW PROFILE
	_start_button(screen).pressed.emit()
	assert_bool(_fs.exists("profile.corrupt")).is_true()
	assert_bool(_fs.exists("profile.sav")).is_false()
	assert_int(Game.save_problem).is_equal(SaveService.Problem.NONE)
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.HOME)


func test_too_new_save_shows_no_button_and_never_writes() -> void:
	var raw: PackedByteArray = SaveSchema.raw_from_document({"schema_version": 9, "profile": {}})
	_fs.files["profile.sav"] = SaveCodec.encode(SaveCodec.MAGIC_PROFILE, 9, raw)
	var before: PackedByteArray = _fs.files["profile.sav"]
	_use_service(SaveService.new(_fs, FakeClock.new(1000), "dev"))
	var r: ScreenRouter = _router(_main())
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.SAVE_PROBLEM)
	var screen: SaveProblemScreen = r.active_screen() as SaveProblemScreen
	assert_bool(_start_button(screen).visible).is_false()
	assert_str((screen.content.get_child(1) as Label).text).is_equal(Strings.get_text("save.too_new_body"))
	assert_array(_fs.files["profile.sav"]).is_equal(before)
	assert_bool(Game.saves.resolve_start_new()).is_false()


func test_notice_shows_once_as_a_toast_on_home() -> void:
	Game.notice = "save.recovered"
	var r: ScreenRouter = _router(_main())
	assert_bool(r.toast_visible()).is_true()
	assert_str(r.toast_text()).is_equal(Strings.get_text("save.recovered"))
	assert_str(Game.notice).is_equal("")


## An interrupted run (checkpoint on the fs) found by a second boot. Returns with `_pending_resume` set.
func _boot_with_a_snapshot() -> void:
	var first: SaveService = SaveService.new(_fs, FakeClock.new(1000), "dev")
	@warning_ignore("return_value_discarded")
	first.load_profile()
	var ctrl: RunController = RunController.new()
	ctrl.last_run_path = RUN_PATH
	first.attach(ctrl)
	@warning_ignore("return_value_discarded")
	first.start_run()
	@warning_ignore("return_value_discarded")
	ctrl.fast_forward(900)
	assert_bool(first.checkpoint_now()).is_true()
	var second: SaveService = SaveService.new(_fs, FakeClock.new(2000), "dev")
	_use_service(second)
	var res: ResumeResult = second.try_resume(Callable(Game, "_resume_config"))
	assert_int(res.status).is_equal(ResumeResult.Status.RESUMED)
	Game.set("_pending_resume", res)
	Game.notice = second.notice


## Design 11 (M3-32 finding): boot shows the title with CONTINUE; CONTINUE lands in the paused, resumed battle
## with the notice on the overlay.
func test_resumed_run_waits_on_the_title_then_continue_resumes_paused() -> void:
	_boot_with_a_snapshot()
	var main: Control = _main()
	var r: ScreenRouter = _router(main)
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.TITLE)
	assert_bool(r.toast_visible()).is_false()  # "RUN RESTORED" waits for the battle
	assert_bool(r.dispatch(AppFlow.Event.CONTINUE)).is_true()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.BATTLE)
	assert_int(Game.controller.state).is_equal(RunController.State.IN_RUN)
	assert_bool(Game.controller.paused).is_true()
	var shell: MobileShell = _shell(main)
	assert_bool(shell.overlay().visible).is_true()
	assert_str(shell.overlay().notice_text()).is_equal(Strings.get_text("save.resumed"))
	shell.resume()
	assert_bool(Game.controller.paused).is_false()
	assert_str(shell.overlay().notice_text()).is_equal("")


## NEW GAME (and Settings > Data) archive the snapshot files; the in-memory resume must go too, or the new game's
## first DEPLOY would resume the old run.
func test_profile_reset_drops_the_pending_resume() -> void:
	_boot_with_a_snapshot()
	var r: ScreenRouter = _router(_main())
	assert_bool(Game.has_pending_resume()).is_true()
	assert_bool(ProfileReset.run(Game.saves)).is_true()
	assert_bool(Game.has_pending_resume()).is_false()
	r.refresh_unlocks()
	assert_bool(r.flow.resume_pending).is_false()
	assert_int(r.flow.target(AppFlow.Event.CONTINUE)).is_equal(AppFlow.Screen.HOME)


func test_menu_audio_follows_the_screen() -> void:
	var r: ScreenRouter = _home_router(_main())
	# --mute keeps the director disabled (start is a no-op); entering the battle must leave the ambience off
	_press_home_deploy(r)
	assert_bool(Game.audio.is_menu_ambience_active()).is_false()


func _shell(main: Control) -> MobileShell:
	for c: Node in main.get_children():
		if c is MobileShell:
			return c
	fail("no shell")
	return null


func _node(main: Control, unique: String) -> Node:
	return main.get_node(unique)


func _visible(main: Control, unique: String) -> bool:
	return (main.get_node(unique) as CanvasItem).visible


func _start_button(screen: SaveProblemScreen) -> Button:
	return screen.content.get_child(2) as Button
