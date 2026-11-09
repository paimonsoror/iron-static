class_name TestAppFlow
extends GdUnitTestSuite
## AppFlow (M3-14): the screen flow table, boot target, opener memory, illegal transitions.

const S := AppFlow.Screen
const E := AppFlow.Event


func _flow(at: AppFlow.Screen, foundry: bool = true) -> AppFlow:
	var f := AppFlow.new()
	f.foundry_unlocked = foundry
	f.enter(at)
	return f


func test_boot_screen_table() -> void:
	# [save_problem, resumed] -> screen
	assert_int(AppFlow.boot_screen(true, false)).is_equal(S.SAVE_PROBLEM)
	assert_int(AppFlow.boot_screen(true, true)).is_equal(S.SAVE_PROBLEM)
	assert_int(AppFlow.boot_screen(false, true)).is_equal(S.BATTLE)
	var plain: int = S.TITLE if AppFlow.TITLE_ENABLED else S.HOME
	assert_int(AppFlow.boot_screen(false, false)).is_equal(plain)


func test_every_spec_row() -> void:
	# [from, event, to]
	var rows: Array = [
		[S.SAVE_PROBLEM, E.START_NEW_PROFILE, S.HOME],
		[S.HOME, E.DEPLOY, S.BATTLE],
		[S.HOME, E.OPEN_FOUNDRY, S.FOUNDRY],
		[S.HOME, E.OPEN_SETTINGS, S.SETTINGS],
		[S.BATTLE, E.RUN_ENDED, S.RESULTS],
		[S.RESULTS, E.DEPLOY, S.BATTLE],
		[S.RESULTS, E.GO_HOME, S.HOME],
		[S.RESULTS, E.OPEN_FOUNDRY, S.FOUNDRY],
		[S.FOUNDRY, E.DEPLOY, S.BATTLE],
		[S.TITLE, E.CONTINUE, S.HOME],
		[S.TITLE, E.NEW_GAME, S.FRAME_BAY],
		[S.TITLE, E.OPEN_SETTINGS, S.SETTINGS],
		[S.FRAME_BAY, E.FRAME_CONFIRMED, S.HOME],
		[S.FRAME_BAY, E.FRAME_BAY_BACK, S.TITLE],
	]
	for row: Array in rows:
		var from: AppFlow.Screen = row[0]
		var event: AppFlow.Event = row[1]
		var want: int = row[2]
		assert_int(_flow(from).apply(event)).is_equal(want)


func test_foundry_and_settings_return_to_their_opener() -> void:
	var f: AppFlow = _flow(S.HOME)
	assert_int(f.apply(E.OPEN_FOUNDRY)).is_equal(S.FOUNDRY)
	assert_int(f.apply(E.BACK_TO_OPENER)).is_equal(S.HOME)
	assert_int(f.apply(E.OPEN_SETTINGS)).is_equal(S.SETTINGS)
	assert_int(f.apply(E.BACK_TO_OPENER)).is_equal(S.HOME)
	var r: AppFlow = _flow(S.RESULTS)
	assert_int(r.apply(E.OPEN_FOUNDRY)).is_equal(S.FOUNDRY)
	assert_int(r.apply(E.BACK_TO_OPENER)).is_equal(S.RESULTS)
	var t: AppFlow = _flow(S.TITLE)
	assert_int(t.apply(E.OPEN_SETTINGS)).is_equal(S.SETTINGS)
	assert_int(t.apply(E.BACK_TO_OPENER)).is_equal(S.TITLE)


func test_foundry_not_reachable_from_home_before_the_first_death() -> void:
	var f: AppFlow = _flow(S.HOME, false)
	assert_int(f.target(E.OPEN_FOUNDRY)).is_equal(AppFlow.NONE)
	assert_int(f.apply(E.OPEN_FOUNDRY)).is_equal(AppFlow.NONE)
	assert_int(f.current).is_equal(S.HOME)
	var r: AppFlow = _flow(S.RESULTS, false)
	assert_int(r.apply(E.OPEN_FOUNDRY)).is_equal(AppFlow.NONE)


func test_illegal_transitions_are_rejected_and_change_nothing() -> void:
	var illegal: Array = [
		[S.HOME, E.RUN_ENDED],
		[S.HOME, E.GO_HOME],
		[S.HOME, E.BACK_TO_OPENER],
		[S.BATTLE, E.DEPLOY],
		[S.BATTLE, E.GO_HOME],
		[S.BATTLE, E.OPEN_FOUNDRY],
		[S.SAVE_PROBLEM, E.DEPLOY],
		[S.SAVE_PROBLEM, E.OPEN_SETTINGS],
		[S.SETTINGS, E.DEPLOY],
		[S.FOUNDRY, E.OPEN_SETTINGS],
		[S.RESULTS, E.RUN_ENDED],
	]
	for row: Array in illegal:
		var from: AppFlow.Screen = row[0]
		var event: AppFlow.Event = row[1]
		var f: AppFlow = _flow(from)
		assert_int(f.apply(event)).is_equal(AppFlow.NONE)
		assert_int(f.current).is_equal(from)


func test_menu_screens_are_the_non_battle_ones() -> void:
	for s: AppFlow.Screen in [S.SAVE_PROBLEM, S.HOME, S.FOUNDRY, S.SETTINGS, S.TITLE, S.FRAME_BAY]:
		assert_bool(AppFlow.is_menu(s)).is_true()
	assert_bool(AppFlow.is_menu(S.BATTLE)).is_false()
	assert_bool(AppFlow.is_menu(S.RESULTS)).is_false()


func test_every_event_target_is_a_known_screen() -> void:
	for from: int in AppFlow.TABLE:
		var row: Dictionary = AppFlow.TABLE[from]
		for event: int in row:
			var to: int = row[event]
			assert_bool(to == AppFlow.OPENER or S.values().has(to)).is_true()


func test_title_flow_rows_and_the_profile_reset_return() -> void:
	assert_bool(AppFlow.TITLE_ENABLED).is_true()
	assert_int(AppFlow.boot_screen(false, false)).is_equal(S.TITLE)
	assert_int(AppFlow.boot_screen(false, true)).is_equal(S.BATTLE)  # a resumed run skips the title
	assert_int(_flow(S.SETTINGS).apply(E.PROFILE_RESET)).is_equal(S.TITLE)
	assert_int(_flow(S.FRAME_BAY).apply(E.BACK_TO_OPENER)).is_equal(AppFlow.NONE)


func test_title_cannot_reach_battle_or_other_screens_directly() -> void:
	for e: AppFlow.Event in [E.DEPLOY, E.OPEN_FOUNDRY, E.GO_HOME, E.RUN_ENDED, E.FRAME_CONFIRMED, E.PROFILE_RESET]:
		var f: AppFlow = _flow(S.TITLE)
		assert_int(f.apply(e)).is_equal(AppFlow.NONE)
		assert_int(f.current).is_equal(S.TITLE)
	assert_int(_flow(S.FRAME_BAY).apply(E.DEPLOY)).is_equal(AppFlow.NONE)
