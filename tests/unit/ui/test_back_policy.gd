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
