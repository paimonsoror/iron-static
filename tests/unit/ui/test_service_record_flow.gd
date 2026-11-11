class_name TestServiceRecordFlow
extends GdUnitTestSuite
## How the Service Record is reached: the AppFlow table, the back policy, the Home RECORD tab and the real router
## (Home -> SERVICE RECORD -> back to Home). `Game` is the autoload: the router test swaps in an in-memory service.

const RUN_PATH: String = "user://runs/test_service_record_flow.json"

var _old_saves: SaveService
var _old_controller: RunController
var _old_problem: SaveService.Problem
var _old_pending: Variant
var _spy: SpyAudioDirector = null


func before_test() -> void:
	SaveKey.reset()
	_old_saves = Game.saves
	_old_controller = Game.controller
	_old_problem = Game.save_problem
	_old_pending = Game.get("_pending_resume")
	Game.controller = RunController.new()
	Game.controller.last_run_path = RUN_PATH
	Game.set("_pending_resume", null)
	Game.notice = ""
	var s := SaveService.new(MemorySaveFs.new(), FakeClock.new(1000), "dev")
	@warning_ignore("return_value_discarded")
	s.load_profile()
	s.attach(Game.controller)
	Game.saves = s
	Game.save_problem = s.problem
	_spy = auto_free(SpyAudioDirector.new())
	AudioHooks.override = _spy


func after_test() -> void:
	AudioHooks.override = null
	Game.saves = _old_saves
	Game.controller = _old_controller
	Game.save_problem = _old_problem
	Game.set("_pending_resume", _old_pending)
	Game.notice = ""


func test_flow_table_opens_the_record_from_home_and_returns_to_the_opener() -> void:
	var f := AppFlow.new()
	f.enter(AppFlow.Screen.HOME)
	assert_int(f.apply(AppFlow.Event.OPEN_RECORD)).is_equal(AppFlow.Screen.SERVICE_RECORD)
	assert_bool(AppFlow.is_menu(AppFlow.Screen.SERVICE_RECORD)).is_true()
	assert_int(f.target(AppFlow.Event.DEPLOY)).is_equal(AppFlow.NONE)  # nothing else leaves it
	assert_int(f.apply(AppFlow.Event.BACK_TO_OPENER)).is_equal(AppFlow.Screen.HOME)
	f.enter(AppFlow.Screen.SETTINGS)
	assert_int(f.target(AppFlow.Event.OPEN_RECORD)).is_equal(AppFlow.NONE)  # Home only


func test_back_goes_back_and_the_flight_recorder_knows_the_screen() -> void:
	var action: BackPolicy.Action = BackPolicy.decide_screen(AppFlow.Screen.SERVICE_RECORD, false, false, false, false)
	assert_int(action).is_equal(BackPolicy.Action.GO_BACK)
	assert_bool(FlightRecorder.SCREEN_RANK.has("service_record")).is_true()
	var names: Array = AppFlow.Screen.keys()
	assert_bool(names.has("SERVICE_RECORD")).is_true()


func _home(runs: int) -> HomeScreen:
	var root: Control = auto_free(Control.new())
	root.size = Vector2(1080.0, 1920.0)
	add_child(root)
	var p := PlayerProfile.fresh(0, "t")
	p.runs_total = runs
	var s: HomeScreen = (load("res://src/ui/home/home_screen.tscn") as PackedScene).instantiate()
	s.setup(p)
	root.add_child(s)
	s.size = root.size
	return s


func test_home_shows_the_record_tab_after_the_first_deployment_and_it_opens_the_screen() -> void:
	var fresh: HomeScreen = _home(0)
	assert_bool(fresh.nav_record.visible).is_false()
	var s: HomeScreen = _home(3)
	await await_idle_frame()
	assert_bool(s.nav_record.visible).is_true()
	assert_bool(s.nav_foundry.visible).is_true()
	assert_float(s.nav_record.size.y).is_greater_equal(148.0)
	var seen: Array[int] = [0]
	s.record_pressed.connect(func() -> void: seen[0] += 1)
	s.nav_record.pressed.emit()
	assert_int(seen[0]).is_equal(1)
	assert_array(_spy.sfx).contains_exactly(["sfx_ui_tap"])
	# the three nav tabs share the row inside the 1080 column
	var row: Rect2 = s.nav_row.get_global_rect()
	assert_float(s.nav_record.get_global_rect().end.x).is_less_equal(row.end.x + 0.5)
	assert_float(s.nav_home.size.x).is_greater(250.0)


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


func test_router_opens_the_record_from_home_and_back_returns() -> void:
	Game.saves.profile.runs_total = 2
	var r: ScreenRouter = _router(_main())
	assert_bool(r.dispatch(AppFlow.Event.CONTINUE)).is_true()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.HOME)
	var home: HomeScreen = r.active_screen() as HomeScreen
	home.record_pressed.emit()  # the signal wired in the registry
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.SERVICE_RECORD)
	var screen: ServiceRecordScreen = r.active_screen() as ServiceRecordScreen
	assert_object(screen).is_not_null()
	assert_int(screen.name_labels.size()).is_greater(20)
	assert_bool(screen.visible).is_true()
	assert_int(r.handle_back(false)).is_equal(BackPolicy.Action.GO_BACK)
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.HOME)
	# the BACK button does the same
	home = r.active_screen() as HomeScreen
	home.record_pressed.emit()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.SERVICE_RECORD)
	(r.active_screen() as ServiceRecordScreen).back_button.pressed.emit()
	assert_int(r.current_screen()).is_equal(AppFlow.Screen.HOME)
	# it refreshes from the profile each time it is shown
	ServiceRecord.note_seconds(Game.saves.profile, 7200)
	home.record_pressed.emit()
	var again: ServiceRecordScreen = r.active_screen() as ServiceRecordScreen
	assert_str(again.value_labels[0].text).is_equal("2h 00m")
