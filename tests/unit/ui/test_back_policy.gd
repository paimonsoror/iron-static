class_name TestBackPolicy
extends GdUnitTestSuite
## BackPolicy (V1-24): the back gesture decision table.


func test_decision_table() -> void:
	# [panel_open, paused, in_battle] -> action
	var table: Array = [
		[true, false, true, BackPolicy.Action.CLOSE_PANEL],
		[true, true, true, BackPolicy.Action.CLOSE_PANEL],
		[true, false, false, BackPolicy.Action.CLOSE_PANEL],
		[false, false, true, BackPolicy.Action.PAUSE],
		[false, true, true, BackPolicy.Action.QUIT],
		[false, false, false, BackPolicy.Action.QUIT],
		[false, true, false, BackPolicy.Action.QUIT],
	]
	for row: Array in table:
		var panel: bool = row[0]
		var paused: bool = row[1]
		var battle: bool = row[2]
		var want: int = row[3]
		assert_int(BackPolicy.decide(panel, paused, battle)).is_equal(want)


func test_screen_table_all_screens_by_paused_and_panel() -> void:
	# BATTLE falls back to the V1-24 table for every (panel_open, paused, in_battle).
	for panel: bool in [false, true]:
		for paused: bool in [false, true]:
			for in_battle: bool in [false, true]:
				var want: BackPolicy.Action = BackPolicy.decide(panel, paused, in_battle)
				assert_int(BackPolicy.decide_screen(AppFlow.Screen.BATTLE, panel, paused, in_battle, false)).is_equal(
					want
				)
	# [screen, armed] -> action with no panel open; paused never changes a menu screen's answer.
	var table: Array = [
		[AppFlow.Screen.SAVE_PROBLEM, false, BackPolicy.Action.QUIT],
		[AppFlow.Screen.HOME, false, BackPolicy.Action.ARM_EXIT],
		[AppFlow.Screen.HOME, true, BackPolicy.Action.QUIT],
		[AppFlow.Screen.FOUNDRY, false, BackPolicy.Action.GO_BACK],
		[AppFlow.Screen.SETTINGS, false, BackPolicy.Action.GO_BACK],
		[AppFlow.Screen.FRAME_BAY, false, BackPolicy.Action.GO_BACK],
		[AppFlow.Screen.RESULTS, false, BackPolicy.Action.GO_HOME],
		[AppFlow.Screen.TITLE, false, BackPolicy.Action.CONFIRM_QUIT],
	]
	for row: Array in table:
		var screen: AppFlow.Screen = row[0]
		var armed: bool = row[1]
		var want: int = row[2]
		for paused: bool in [false, true]:
			assert_int(BackPolicy.decide_screen(screen, false, paused, false, armed)).is_equal(want)
			# an open debug panel closes first on every screen
			assert_int(BackPolicy.decide_screen(screen, true, paused, false, armed)).is_equal(
				BackPolicy.Action.CLOSE_PANEL
			)


func test_an_open_dialog_closes_first_on_every_menu_screen_but_not_in_battle() -> void:
	for s: AppFlow.Screen in [
		AppFlow.Screen.TITLE,
		AppFlow.Screen.HOME,
		AppFlow.Screen.FOUNDRY,
		AppFlow.Screen.SETTINGS,
		AppFlow.Screen.FRAME_BAY,
		AppFlow.Screen.SAVE_PROBLEM,
	]:
		assert_int(BackPolicy.decide_screen(s, false, false, false, false, true)).is_equal(
			BackPolicy.Action.CLOSE_DIALOG
		)
	assert_int(BackPolicy.decide_screen(AppFlow.Screen.TITLE, false, false, false, false)).is_equal(
		BackPolicy.Action.CONFIRM_QUIT
	)
	assert_int(BackPolicy.decide_screen(AppFlow.Screen.BATTLE, false, false, true, false, true)).is_equal(
		BackPolicy.Action.PAUSE
	)
