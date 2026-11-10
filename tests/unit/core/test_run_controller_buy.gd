class_name TestRunControllerBuy
extends GdUnitTestSuite
## M2-12: queued buys, input log timing, best-wave stub, run record file.

const MAX_TICKS: int = 60000
const TEST_PATH: String = "user://runs/test_last_run.json"
const FRAME_S: float = 1.0 / 30.0


func _controller() -> RunController:
	var c := RunController.new()
	c.last_run_path = TEST_PATH
	return c


func _row(c: RunController, id: String) -> int:
	for i: int in c.world.config.upgrades.size():
		if c.world.config.upgrades[i].id == id:
			return i
	return -1


func test_buy_is_queued_then_applied_at_next_update() -> void:
	var c: RunController = _controller()
	var w: SimWorld = c.start_run(1)
	var i: int = _row(c, "laser_output")
	assert_bool(c.request_buy(i, 1)).is_true()
	assert_float(w.stats.laser_output).is_equal_approx(10.0, 1.0e-9)  # not applied yet
	assert_int(w.input_log.size()).is_equal(0)
	@warning_ignore("return_value_discarded")
	c.update(FRAME_S)
	assert_float(w.stats.laser_output).is_equal_approx(11.0, 1.0e-9)
	assert_float(w.economy.scrap.to_float()).is_less(230.0)
	assert_int(w.input_log.size()).is_equal(1)
	assert_int(w.input_log.ticks[0]).is_equal(0)  # logged at the tick about to run


func test_buy_while_paused_lands_on_current_tick() -> void:
	var c: RunController = _controller()
	var w: SimWorld = c.start_run(1)
	for k: int in 5:
		@warning_ignore("return_value_discarded")
		c.update(FRAME_S)
	c.paused = true
	var t: int = w.tick
	assert_bool(c.request_buy(_row(c, "laser_output"), 1)).is_true()
	@warning_ignore("return_value_discarded")
	c.update(FRAME_S)
	assert_int(w.tick).is_equal(t)
	assert_int(w.input_log.size()).is_equal(1)
	assert_int(w.input_log.ticks[0]).is_equal(t)


func test_request_dropped_outside_run() -> void:
	var c: RunController = _controller()
	assert_bool(c.request_buy(0, 1)).is_false()
	@warning_ignore("return_value_discarded")
	c.start_run(1, true, 60)
	assert_bool(c.request_buy(0, 1)).is_false()


func test_run_to_death_updates_best_wave_and_record_replays() -> void:
	var c: RunController = _controller()
	var w: SimWorld = c.start_run(1)
	var frame: int = 0
	while c.state == RunController.State.IN_RUN and frame < MAX_TICKS:
		if frame % 20 == 0:
			@warning_ignore("return_value_discarded")
			c.request_buy(floori(float(frame) / 20.0) % 4, 1)
		@warning_ignore("return_value_discarded")
		c.update(FRAME_S)
		frame += 1
	assert_int(c.state).is_equal(RunController.State.RESULTS)
	assert_int(w.input_log.size()).is_greater(1)
	assert_int(c.best_wave_s1).is_equal(w.run.death_wave)
	assert_bool(FileAccess.file_exists(TEST_PATH)).is_true()
	var rec: RunRecord = RunRecord.from_json(FileAccess.get_file_as_string(TEST_PATH))
	assert_object(rec).is_not_null()
	assert_int(rec.commands.size()).is_equal(w.input_log.size())
	var cfg: SimConfig = SimConfigLoader.load_default(99)
	assert_str(Replay.run(cfg, rec, MAX_TICKS)).is_equal(w.state_hash())


func test_next_run_unlocks_rows_when_best_wave_crosses_gate() -> void:
	var c: RunController = _controller()
	var w1: SimWorld = c.start_run(1)
	var hidden: int = 0
	for v: int in w1.visible:
		hidden += 1 if v == 0 else 0
	assert_int(hidden).is_greater(0)
	c.best_wave_s1 = 100
	var w2: SimWorld = c.redeploy()
	assert_int(w2.config.best_wave_s1).is_equal(100)
	for v: int in w2.visible:
		assert_int(v).is_equal(1)


func test_load_run_does_not_update_best_wave() -> void:
	var c: RunController = _controller()
	c.best_wave_s1 = 3
	@warning_ignore("return_value_discarded")
	c.start_run(1, true, 0)
	@warning_ignore("return_value_discarded")
	c.fast_forward(600)
	c.world.end_run()
	@warning_ignore("return_value_discarded")
	c.fast_forward(1)
	assert_int(c.state).is_equal(RunController.State.RESULTS)
	assert_int(c.best_wave_s1).is_equal(3)
