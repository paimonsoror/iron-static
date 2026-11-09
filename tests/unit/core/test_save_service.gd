class_name TestSaveService
extends GdUnitTestSuite
## SaveService on MemorySaveFs: boot states, banking, blocked writes, seeds, Foundry (M3-12).

const TEST_RUN_PATH: String = "user://runs/test_save_service_run.json"
const MAX_TICKS: int = 60000

var fs: MemorySaveFs
var clock: FakeClock


func before_test() -> void:
	SaveKey.reset()
	fs = MemorySaveFs.new()
	clock = FakeClock.new(1000)


func _svc() -> SaveService:
	return SaveService.new(fs, clock, "dev1")


func _boot() -> SaveService:
	var s: SaveService = _svc()
	@warning_ignore("return_value_discarded")
	s.load_profile()
	return s


func _bank(s: SaveService, run_id: int, wave: int, data: String) -> bool:
	return s.bank_run(RunSummary.make(run_id, wave, BigNum.parse(data), 1800))


func _flip(path: String) -> void:
	var b: PackedByteArray = fs.files[path]
	b[16] = b[16] ^ 1
	fs.files[path] = b


func test_fresh_boot_writes_nothing_then_first_bank_persists() -> void:
	var s: SaveService = _boot()
	assert_int(s.last_load_status).is_equal(LoadResult.Status.FRESH)
	assert_int(fs.files.size()).is_equal(0)
	assert_str(s.profile.device_id).is_equal("dev1")
	assert_bool(_bank(s, 1, 7, "250")).is_true()
	assert_bool(s.last_bank_saved).is_true()
	var back: SaveService = _boot()
	assert_int(back.last_load_status).is_equal(LoadResult.Status.OK)
	assert_str(back.profile.data.to_text()).is_equal(BigNum.parse("250").to_text())
	assert_int(back.profile.best_wave_s1()).is_equal(7)


func test_kill_after_bank_keeps_the_banked_run() -> void:
	var s: SaveService = _boot()
	assert_bool(_bank(s, 1, 5, "10")).is_true()
	s = null  # killed: no further save call
	assert_str(_boot().profile.data.to_text()).is_equal(BigNum.parse("10").to_text())


func test_corrupt_live_with_good_backup_recovers_and_repairs() -> void:
	var s: SaveService = _boot()
	assert_bool(_bank(s, 1, 5, "10")).is_true()
	assert_bool(_bank(s, 2, 6, "5")).is_true()
	_flip("profile.sav")
	var r: SaveService = _boot()
	assert_int(r.last_load_status).is_equal(LoadResult.Status.RECOVERED)
	assert_str(r.notice).is_equal("save.recovered")
	assert_str(r.profile.data.to_text()).is_equal(BigNum.parse("10").to_text())  # the backup holds the previous good state
	assert_int(_boot().last_load_status).is_equal(LoadResult.Status.OK)  # repaired at once


func test_both_files_corrupt_blocks_writes_and_leaves_bytes_identical() -> void:
	var s: SaveService = _boot()
	assert_bool(_bank(s, 1, 5, "10")).is_true()
	assert_bool(_bank(s, 2, 6, "5")).is_true()
	_flip("profile.sav")
	_flip("profile.bak")
	var live: PackedByteArray = fs.files["profile.sav"]
	var bak: PackedByteArray = fs.files["profile.bak"]
	fs.ops = 0
	var r: SaveService = _boot()
	assert_int(r.problem).is_equal(SaveService.Problem.CORRUPT)
	assert_bool(r.writes_blocked).is_true()
	assert_bool(r.save_now()).is_false()
	assert_bool(_bank(r, 1, 9, "99")).is_true()  # in memory only
	assert_bool(r.last_bank_saved).is_false()
	assert_int(fs.ops).is_equal(0)
	assert_array(fs.files["profile.sav"]).is_equal(live)
	assert_array(fs.files["profile.bak"]).is_equal(bak)
	assert_bool(r.resolve_start_new()).is_true()
	assert_bool(fs.exists("profile.corrupt")).is_true()
	assert_bool(r.writes_blocked).is_false()
	assert_bool(r.save_now()).is_true()


func test_newer_schema_is_too_new_and_never_unblocks() -> void:
	var raw: PackedByteArray = SaveSchema.raw_from_document({"schema_version": 9, "profile": {}})
	fs.files["profile.sav"] = SaveCodec.encode(SaveCodec.MAGIC_PROFILE, 9, raw)
	var before: PackedByteArray = fs.files["profile.sav"]
	var r: SaveService = _boot()
	assert_int(r.problem).is_equal(SaveService.Problem.TOO_NEW)
	assert_bool(r.writes_blocked).is_true()
	assert_bool(r.resolve_start_new()).is_false()
	assert_bool(r.writes_blocked).is_true()
	assert_bool(r.save_now()).is_false()
	assert_array(fs.files["profile.sav"]).is_equal(before)
	assert_int(fs.files.size()).is_equal(1)


func test_banking_twice_for_the_same_run_adds_data_once() -> void:
	var s: SaveService = _boot()
	assert_bool(_bank(s, 1, 5, "10")).is_true()
	assert_bool(_bank(s, 1, 5, "10")).is_false()
	assert_str(s.profile.data.to_text()).is_equal(BigNum.parse("10").to_text())
	assert_int(s.profile.runs_total).is_equal(1)


func test_failed_write_retries_once_on_next_tick() -> void:
	var s: SaveService = _boot()
	s.profile.run_counter = 3
	fs.fail_at(1)
	assert_bool(s.save_now()).is_false()
	assert_str(s.last_error).is_not_empty()
	@warning_ignore("return_value_discarded")
	s.tick(0.016)
	assert_str(s.last_error).is_empty()
	assert_int(_boot().profile.run_counter).is_equal(3)


func test_run_start_seed_follows_run_counter() -> void:
	var s: SaveService = _boot()
	var c: RunController = RunController.new()
	c.last_run_path = TEST_RUN_PATH
	s.attach(c)
	@warning_ignore("return_value_discarded")
	s.start_run()
	assert_int(c.seed_value).is_equal(RunController.DEFAULT_SEED)
	assert_int(c.run_id).is_equal(1)
	@warning_ignore("return_value_discarded")
	s.start_run()
	assert_int(c.seed_value).is_equal(RunController.DEFAULT_SEED + 1)
	assert_int(s.profile.run_counter).is_equal(2)
	assert_bool(s.scheduler.is_pending()).is_true()


func test_foundry_levels_reach_the_run_and_replay_reproduces_the_hash() -> void:
	var s: SaveService = _boot()
	s.profile.set_foundry_level("laser_output", 6)
	s.profile.set_foundry_level("hull_integrity", 3)
	var c: RunController = RunController.new()
	c.last_run_path = TEST_RUN_PATH
	s.attach(c)
	@warning_ignore("return_value_discarded")
	s.start_run()
	var total: int = 0
	for lv: int in c.world.config.foundry_levels:
		total += lv
	assert_int(total).is_equal(9)
	@warning_ignore("return_value_discarded")
	c.fast_forward(MAX_TICKS)
	assert_int(c.state).is_equal(RunController.State.RESULTS)
	var rec: RunRecord = RunRecord.from_world(c.world)
	var cfg: SimConfig = SimConfigLoader.load_default(c.seed_value)
	SimConfigLoader.apply_foundry(cfg, s.profile.foundry)
	assert_str(Replay.run(cfg, rec, MAX_TICKS)).is_equal(rec.final_hash)
	assert_int(s.profile.runs_total).is_equal(1)  # banked by the run_ended handler


func test_debug_run_banks_nothing_and_keeps_best_wave() -> void:
	var s: SaveService = _boot()
	var c: RunController = RunController.new()
	c.last_run_path = TEST_RUN_PATH
	s.attach(c)
	@warning_ignore("return_value_discarded")
	c.start_run(1, true, 0)  # invulnerable debug run
	for i: int in 3000:
		c.world.step()
	c.world.end_run()
	@warning_ignore("return_value_discarded")
	c.fast_forward(1)
	assert_int(c.state).is_equal(RunController.State.RESULTS)
	assert_int(s.profile.runs_total).is_equal(0)
	assert_int(s.profile.best_wave_s1()).is_equal(0)
	assert_str(s.profile.data.to_text()).is_equal(BigNum.parse("0").to_text())
	assert_int(fs.files.size()).is_equal(0)


func test_last_unlocked_frames_reports_the_new_unlocks() -> void:
	var s: SaveService = _boot()
	assert_bool(_bank(s, 1, 1, "1")).is_true()
	assert_array(s.last_unlocked_frames).is_empty()
	assert_bool(_bank(s, 2, 8, "1")).is_true()
	assert_array(s.last_unlocked_frames).is_equal(["bulwark"])
	assert_bool(_bank(s, 3, 8, "1")).is_true()
	assert_array(s.last_unlocked_frames).is_empty()


## A snapshot of a run in `mode` checkpointed by `s`, then made stale (SimVersion 2), so try_resume banks it.
func _stale_snapshot(s: SaveService, mode: String) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(5)
	@warning_ignore("return_value_discarded")
	SimConfigLoader.apply_mode(cfg, "purge" if mode == "purge" else "timed")
	var w: SimWorld = SimWorld.new(cfg)
	for i: int in 1500:
		w.step()
	assert_bool(s.checkpointer.checkpoint(w, 1)).is_true()
	var dec: DecodeResult = SaveCodec.decode(SaveCodec.MAGIC_SNAPSHOT, fs.read("run_snapshot.sav"), 0xFFFF)
	var d: Dictionary = bytes_to_var(dec.raw)
	d["sim_version"] = 2
	d["mode"] = mode
	fs.files["run_snapshot.sav"] = SaveCodec.encode(SaveCodec.MAGIC_SNAPSHOT, 1, var_to_bytes(d))
	return w


func _mode_factory() -> Callable:
	return func(info: SnapshotInfo) -> SimConfig:
		var cfg: SimConfig = SimConfigLoader.load_default(info.seed_value)
		@warning_ignore("return_value_discarded")
		SimConfigLoader.apply_mode(cfg, info.wave_mode)
		return cfg


## Merge glue of M4-05 and M4-07: a PURGE run ended by an update banks to the PURGE record, never to TIMED.
func test_purge_run_ended_by_update_banks_the_purge_record() -> void:
	var s: SaveService = _boot()
	var w: SimWorld = _stale_snapshot(s, "purge")
	var res: ResumeResult = s.try_resume(_mode_factory())
	assert_int(res.status).is_equal(ResumeResult.Status.ENDED_BY_UPDATE)
	assert_int(w.wave).is_greater(1)
	assert_int(s.profile.best_wave_of_mode("purge", 1)).is_equal(w.wave)
	assert_int(s.profile.best_wave_s1()).is_equal(0)


func test_unknown_mode_ended_by_update_banks_as_timed() -> void:
	var s: SaveService = _boot()
	var w: SimWorld = _stale_snapshot(s, "gauntlet")
	var res: ResumeResult = s.try_resume(_mode_factory())
	assert_int(res.status).is_equal(ResumeResult.Status.ENDED_BY_UPDATE)
	assert_int(s.profile.best_wave_s1()).is_equal(w.wave)
	assert_int(s.profile.best_wave_of_mode("purge", 1)).is_equal(0)
