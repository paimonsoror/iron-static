class_name TestRunAbort
extends GdUnitTestSuite
## ABORT MISSION (pause menu): RunController.abort_run, banking exactly like a death, the run record's "ended" key and
## the replay of an aborted record to its final hash.

const RUN_PATH: String = "user://runs/test_run_abort.json"
const MAX_TICKS: int = 60000

var _fs: MemorySaveFs
var _ended: Array[int] = []
var _aborted: Array[int] = []


func before_test() -> void:
	SaveKey.reset()
	_fs = MemorySaveFs.new()
	_ended.clear()
	_aborted.clear()


func _controller() -> RunController:
	var c := RunController.new()
	c.last_run_path = RUN_PATH
	c.run_ended.connect(func(_w: SimWorld) -> void: _ended.append(1))
	c.run_aborted.connect(func(_w: SimWorld) -> void: _aborted.append(1))
	return c


func _service(c: RunController) -> SaveService:
	var s := SaveService.new(_fs, FakeClock.new(5), "x")
	@warning_ignore("return_value_discarded")
	s.load_profile()
	s.attach(c)
	return s


func _record() -> RunRecord:
	return RunRecord.from_json(FileAccess.get_file_as_string(RUN_PATH))


func test_abort_ends_the_live_run_without_ending_the_world() -> void:
	var c: RunController = _controller()
	@warning_ignore("return_value_discarded")
	c.start_run(3)
	@warning_ignore("return_value_discarded")
	c.fast_forward(240)
	var tick: int = c.world.tick
	var hash_before: String = c.world.state_hash()
	assert_bool(c.abort_run()).is_true()
	assert_int(c.state).is_equal(RunController.State.RESULTS)
	assert_int(_aborted.size()).is_equal(1)
	assert_int(_ended.size()).is_equal(0)
	assert_bool(c.world.is_over()).is_false()
	assert_int(c.world.tick).is_equal(tick)
	assert_str(c.world.state_hash()).is_equal(hash_before)  # the sim was not touched
	assert_bool(c.abort_run()).is_false()  # nothing left to abort
	assert_int(_aborted.size()).is_equal(1)


func test_abort_refused_while_loading_or_when_over() -> void:
	var c: RunController = _controller()
	assert_bool(c.abort_run()).is_false()  # BOOT
	@warning_ignore("return_value_discarded")
	c.start_run(3, true, 40)
	assert_bool(c.abort_run()).is_false()  # debug load fast-forward
	var d: RunController = _controller()
	@warning_ignore("return_value_discarded")
	d.start_run(3)
	@warning_ignore("return_value_discarded")
	d.fast_forward(MAX_TICKS)
	assert_int(d.state).is_equal(RunController.State.RESULTS)
	assert_bool(d.abort_run()).is_false()


func test_aborted_record_has_ended_key_and_died_record_is_unchanged() -> void:
	var c: RunController = _controller()
	@warning_ignore("return_value_discarded")
	c.start_run(3)
	@warning_ignore("return_value_discarded")
	c.fast_forward(300)
	assert_bool(c.abort_run()).is_true()
	var text: String = FileAccess.get_file_as_string(RUN_PATH)
	assert_str(text).contains('"ended":"aborted"')
	var rec: RunRecord = RunRecord.from_json(text)
	assert_bool(rec.aborted).is_true()
	assert_int(rec.final_tick).is_equal(c.world.tick)
	assert_int(rec.death_wave).is_equal(c.world.wave)
	assert_str(rec.to_json()).is_equal(text)  # round trip
	# A death keeps its JSON byte-identical: no "ended" key at all.
	var d: RunController = _controller()
	@warning_ignore("return_value_discarded")
	d.start_run(3)
	@warning_ignore("return_value_discarded")
	d.fast_forward(MAX_TICKS)
	var died: String = FileAccess.get_file_as_string(RUN_PATH)
	assert_str(died).not_contains("ended")
	assert_bool(RunRecord.from_json(died).aborted).is_false()
	assert_int(_ended.size()).is_equal(1)


## Aborted records replay to their final hash: they stop at final_tick (also with a huge max_ticks), including a
## buy applied while paused on the abort tick.
func test_aborted_record_replays_to_its_final_hash() -> void:
	var c: RunController = _controller()
	@warning_ignore("return_value_discarded")
	c.start_run(3)
	for i: int in 8:
		@warning_ignore("return_value_discarded")
		c.fast_forward(45)
		@warning_ignore("return_value_discarded")
		c.world.command_buy(i % 4, 1)
	@warning_ignore("return_value_discarded")
	c.world.command_buy(0, 1)  # logged at the abort tick itself (a buy while paused)
	assert_bool(c.world.is_over()).is_false()
	assert_bool(c.abort_run()).is_true()
	var rec: RunRecord = _record()
	assert_bool(rec.aborted).is_true()
	assert_int(rec.commands.size()).is_greater(3)
	assert_int(rec.commands.ticks[rec.commands.size() - 1]).is_equal(rec.final_tick)
	var w: SimWorld = Replay.run_world(SimConfigLoader.load_default(rec.seed_value), rec, MAX_TICKS)
	assert_int(w.tick).is_equal(rec.final_tick)
	assert_bool(w.is_over()).is_false()
	assert_str(w.state_hash()).is_equal(rec.final_hash)
	assert_str(Replay.run(SimConfigLoader.load_default(rec.seed_value), rec, rec.final_tick + 500)).is_equal(
		rec.final_hash
	)
	var cps: PackedStringArray = Replay.checkpoints(
		SimConfigLoader.load_default(rec.seed_value), rec, PackedInt32Array([100, rec.final_tick + 90])
	)
	assert_str(cps[1]).is_equal("")  # beyond the abort: never reached


func test_abort_banks_like_a_death_and_clears_the_snapshot() -> void:
	var c: RunController = _controller()
	var s: SaveService = _service(c)
	@warning_ignore("return_value_discarded")
	s.start_run("timed")
	@warning_ignore("return_value_discarded")
	c.fast_forward(600)
	assert_bool(c.world.is_over()).is_false()
	assert_bool(s.checkpoint_now()).is_true()
	var wave: int = c.world.wave
	var data: BigNum = c.world.economy.data_run
	var data_before: BigNum = s.profile.data
	assert_bool(c.abort_run()).is_true()
	assert_bool(s.last_bank_saved).is_true()
	assert_str(s.profile.data.to_text()).is_equal(data_before.add(data).to_text())
	assert_int(s.profile.best_wave_of_mode("timed", 1)).is_equal(wave)
	assert_int(c.best_wave_s1).is_equal(wave)
	assert_int(s.profile.runs_total).is_equal(1)
	assert_int(s.profile.last_banked_run).is_equal(c.run_id)
	var again: SaveService = _service(_controller())
	assert_int(again.profile.runs_total).is_equal(1)
	var res: ResumeResult = again.try_resume(
		func(info: SnapshotInfo) -> SimConfig: return SimConfigLoader.load_default(info.seed_value)
	)
	assert_int(res.status).is_not_equal(ResumeResult.Status.RESUMED)


func test_abort_in_purge_raises_only_the_purge_record_and_timed_abort_the_timed_one() -> void:
	var c: RunController = _controller()
	var s: SaveService = _service(c)
	@warning_ignore("return_value_discarded")
	s.profile.unlock_mode("purge")
	@warning_ignore("return_value_discarded")
	s.start_run("purge")
	@warning_ignore("return_value_discarded")
	c.fast_forward(900)
	var wave: int = c.world.wave
	assert_bool(c.abort_run()).is_true()
	assert_int(s.profile.best_wave_of_mode("purge", 1)).is_equal(wave)
	assert_int(s.profile.best_wave_of_mode("timed", 1)).is_equal(0)
	assert_int(c.best_wave_s1).is_equal(0)  # only TIMED feeds the session best (Q71)
	@warning_ignore("return_value_discarded")
	s.start_run("timed")
	@warning_ignore("return_value_discarded")
	c.fast_forward(900)
	var timed_wave: int = c.world.wave
	assert_bool(c.abort_run()).is_true()
	assert_int(s.profile.best_wave_of_mode("timed", 1)).is_equal(timed_wave)
	assert_int(s.profile.best_wave_of_mode("purge", 1)).is_equal(wave)


func test_abort_unlocks_modes_and_frames_like_a_banked_death() -> void:
	var c: RunController = _controller()
	var s: SaveService = _service(c)
	var need: int = ModeRules.find_def(ModeRules.load_defs(), "purge").unlock_best_timed_wave
	@warning_ignore("return_value_discarded")
	s.start_run("timed")
	c.world.wave = need  # the run is already at the unlock wave when the player aborts
	assert_bool(c.abort_run()).is_true()
	assert_array(s.last_unlocked_modes).is_equal(["purge"])
	assert_bool(s.profile.mode_unlocked("purge")).is_true()
	assert_int(s.profile.best_wave_s1()).is_equal(need)


func test_debug_load_run_abort_banks_nothing() -> void:
	var c: RunController = _controller()
	var s: SaveService = _service(c)
	@warning_ignore("return_value_discarded")
	c.start_run(3, true)  # invulnerable debug run: banks_rewards() is false
	assert_bool(c.abort_run()).is_true()
	assert_int(s.profile.runs_total).is_equal(0)
	assert_int(s.profile.best_wave_s1()).is_equal(0)
