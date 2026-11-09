class_name TestRunControllerDraft
extends GdUnitTestSuite
## M4-15 stopgap: until the draft overlay (M4-16) the controller settles an open draft with the first offer, so the
## playable build never freezes at wave 10.

const TEST_PATH: String = "user://runs/test_last_run_draft.json"
const PAST_WAVE_10: int = 10 * Ticks.WAVE_TICKS + 300


func _controller() -> RunController:
	var c := RunController.new()
	c.last_run_path = TEST_PATH
	return c


func test_stopgap_auto_picks_the_first_offer_and_keeps_going() -> void:
	var c: RunController = _controller()
	var w: SimWorld = c.start_run(1, true)  # invulnerable: reaches wave 10
	assert_bool(c.auto_pick_draft).is_true()
	@warning_ignore("return_value_discarded")
	c.fast_forward(PAST_WAVE_10)
	assert_bool(w.is_draft_open()).is_false()
	assert_int(w.tick).is_greater_equal(PAST_WAVE_10 - 1)
	assert_int(w.patches.total_picks).is_equal(1)
	assert_int(w.input_log.size()).is_equal(1)
	assert_int(w.input_log.kinds[0]).is_equal(InputLog.CMD_PICK)
	assert_int(w.input_log.arg_a[0]).is_equal(0)


func test_update_settles_a_draft_between_frames() -> void:
	var c: RunController = _controller()
	var w: SimWorld = c.start_run(1, true)
	while not w.is_draft_open():  # open the draft without the controller
		w.step()
	@warning_ignore("return_value_discarded")
	c.update(1.0 / 30.0)
	assert_bool(w.is_draft_open()).is_false()
	assert_int(w.patches.total_picks).is_equal(1)


func test_without_the_stopgap_the_world_waits() -> void:
	var c: RunController = _controller()
	c.auto_pick_draft = false
	var w: SimWorld = c.start_run(1, true)
	@warning_ignore("return_value_discarded")
	c.fast_forward(PAST_WAVE_10)
	assert_bool(w.is_draft_open()).is_true()
	assert_int(w.tick).is_equal(10 * Ticks.WAVE_TICKS)
