class_name TestResultsFlow
extends GdUnitTestSuite
## M3-17 redeploy flow in the real main scene: death -> results -> tap REDEPLOY is one tap and the next run starts
## in the same frame (taps and frames are logged). Also FOUNDRY and HOME taps route through the router.

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
	Game.controller = RunController.new()
	Game.controller.last_run_path = "user://runs/test_results_flow.json"
	Game.set("_pending_resume", null)
	Game.notice = ""
	var s := SaveService.new(MemorySaveFs.new(), FakeClock.new(1000), "dev")
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


func _to_results() -> Array:
	var main: Control = (load("res://src/ui/main.tscn") as PackedScene).instantiate()
	main.size = Vector2(1080.0, 2400.0)
	add_child(main)
	auto_free(main)
	var router: ScreenRouter = null
	for c: Node in main.get_children():
		if c is ScreenRouter:
			router = c
			router.quits_tree = false
	assert_bool(router.dispatch(AppFlow.Event.CONTINUE)).is_true()  # boot is the title
	assert_bool(router.dispatch(AppFlow.Event.DEPLOY)).is_true()
	@warning_ignore("return_value_discarded")
	Game.controller.fast_forward(60000)
	assert_int(router.current_screen()).is_equal(AppFlow.Screen.RESULTS)
	return [main, router]


func test_redeploy_is_one_tap_and_starts_the_next_run_at_once() -> void:
	var parts: Array = _to_results()
	var main: Control = parts[0]
	var router: ScreenRouter = parts[1]
	var overlay: ResultsOverlay = main.get_node("%ResultsOverlay")
	var taps: int = 0
	var frames: int = 0
	var first_run: int = Game.controller.run_id
	taps += 1
	(overlay.get_node("%RedeployButton") as Button).pressed.emit()
	while Game.controller.run_id == first_run and frames < 10:
		await await_idle_frame()
		frames += 1
	assert_int(taps).is_equal(1)
	assert_int(frames).is_equal(0)
	assert_int(router.current_screen()).is_equal(AppFlow.Screen.BATTLE)
	assert_int(Game.controller.state).is_equal(RunController.State.IN_RUN)
	assert_int(Game.controller.world.tick).is_less_equal(1)
	Log.info("[M3-17] redeploy: taps=%d frames_to_new_run=%d" % [taps, frames])


func test_foundry_tap_opens_foundry_and_back_returns_to_results() -> void:
	var parts: Array = _to_results()
	var main: Control = parts[0]
	var router: ScreenRouter = parts[1]
	var overlay: ResultsOverlay = main.get_node("%ResultsOverlay")
	assert_bool((overlay.get_node("%FoundryButton") as Control).visible).is_true()
	(overlay.get_node("%FoundryButton") as Button).pressed.emit()
	assert_int(router.current_screen()).is_equal(AppFlow.Screen.FOUNDRY)
	assert_bool((router.active_screen() as FoundryScreen).intro_open()).is_true()  # FO-1: the first back closes it
	@warning_ignore("return_value_discarded")
	router.handle_back(false)
	assert_int(router.current_screen()).is_equal(AppFlow.Screen.FOUNDRY)
	assert_int(router.handle_back(false)).is_equal(BackPolicy.Action.GO_BACK)
	assert_int(router.current_screen()).is_equal(AppFlow.Screen.RESULTS)
	assert_bool(overlay.visible).is_true()


func test_home_tap_goes_home() -> void:
	var parts: Array = _to_results()
	var main: Control = parts[0]
	var router: ScreenRouter = parts[1]
	var overlay: ResultsOverlay = main.get_node("%ResultsOverlay")
	(overlay.get_node("%HomeButton") as Button).pressed.emit()
	assert_int(router.current_screen()).is_equal(AppFlow.Screen.HOME)
	assert_bool(overlay.visible).is_false()
