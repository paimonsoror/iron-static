class_name TestDriverSlowmoHash
extends GdUnitTestSuite
## V1-14: slow-mo is a wall-time accumulator scale only. Same (seed, config, input log) through the real
## RunController/TickDriver gives the same final state hash with and without it.

const TICKS: int = 900
const BUY_TICK: int = 60
const FRAME_S: float = 1.0 / 30.0
const NO_BUDGET_LIMIT: int = 1_000_000_000
const MAX_FRAMES: int = 100000


func _run(slow: bool) -> Array:
	var c := RunController.new()
	c.last_run_path = "user://runs/test_slowmo_run.json"
	var w: SimWorld = c.start_run(7)
	c.driver.budget_usec = NO_BUDGET_LIMIT
	var row: int = -1
	for i: int in w.config.upgrades.size():
		if w.config.upgrades[i].id == "laser_output":
			row = i
	var frames: int = 0
	c.driver.tick_limit = BUY_TICK
	while w.tick < BUY_TICK and frames < MAX_FRAMES:
		frames += 1
		@warning_ignore("return_value_discarded")
		c.update(FRAME_S)
	assert_bool(c.request_buy(row, 1)).is_true()
	c.driver.tick_limit = TICKS
	var slow_until: int = frames + 60  # forced slow-mo: factor 0.3 for 2 s of wall time at 30 fps
	while w.tick < TICKS and frames < MAX_FRAMES:
		c.time_scale = 0.3 if slow and frames < slow_until else 1.0
		frames += 1
		@warning_ignore("return_value_discarded")
		c.update(FRAME_S)
	assert_int(w.tick).is_equal(TICKS)
	return [w.state_hash(), frames, w.input_log.size(), w.input_log.ticks[0]]


func test_slowmo_changes_pacing_not_the_hash() -> void:
	var normal: Array = _run(false)
	var slow: Array = _run(true)
	assert_str(slow[0]).is_equal(normal[0])
	var normal_frames: int = normal[1]
	assert_int(slow[1]).is_greater(normal_frames)  # more wall frames for the same ticks
	assert_int(slow[2]).is_equal(1)
	var normal_tick: int = normal[3]
	assert_int(slow[3]).is_equal(normal_tick)  # the buy landed on the same tick
	assert_int(normal[3]).is_equal(BUY_TICK)
