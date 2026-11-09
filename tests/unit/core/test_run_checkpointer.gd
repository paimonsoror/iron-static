class_name TestRunCheckpointer
extends GdUnitTestSuite
## RunCheckpointer: checkpoint, resume, discard rules (M3-13).

const SEED: int = 5


func _factory() -> Callable:
	return func(info: SnapshotInfo) -> SimConfig:
		var cfg: SimConfig = SimConfigLoader.load_default(info.seed_value)
		cfg.best_wave_s1 = info.best_wave_s1
		return cfg


func _world(ticks: int) -> SimWorld:
	var w: SimWorld = SimWorld.new(SimConfigLoader.load_default(SEED))
	for i: int in ticks:
		w.step()
	return w


func _store(fs: MemorySaveFs) -> RunCheckpointer:
	return RunCheckpointer.new(RunCheckpointer.make_store(fs))


func test_checkpoint_then_resume_lands_on_the_same_hash() -> void:
	var fs: MemorySaveFs = MemorySaveFs.new()
	var cp: RunCheckpointer = _store(fs)
	var w: SimWorld = _world(500)
	assert_bool(cp.checkpoint(w, 2)).is_true()
	var res: ResumeResult = _store(fs).try_resume(_factory(), 1)
	assert_int(res.status).is_equal(ResumeResult.Status.RESUMED)
	assert_str(res.world.state_hash()).is_equal(w.state_hash())
	assert_int(res.world.tick).is_equal(500)


func test_no_snapshot_is_none() -> void:
	var res: ResumeResult = _store(MemorySaveFs.new()).try_resume(_factory(), 0)
	assert_int(res.status).is_equal(ResumeResult.Status.NONE)


func test_flipped_bit_without_backup_deletes_the_snapshot() -> void:
	var fs: MemorySaveFs = MemorySaveFs.new()
	var cp: RunCheckpointer = _store(fs)
	assert_bool(cp.checkpoint(_world(100), 2)).is_true()
	var b: PackedByteArray = fs.files["run_snapshot.sav"]
	b[20] = b[20] ^ 1
	fs.files["run_snapshot.sav"] = b
	var res: ResumeResult = _store(fs).try_resume(_factory(), 1)
	assert_int(res.status).is_equal(ResumeResult.Status.DISCARDED_DAMAGED)
	assert_bool(fs.exists("run_snapshot.sav")).is_false()
	assert_bool(fs.exists("run_snapshot.bak")).is_false()


func test_snapshot_of_a_banked_run_is_deleted() -> void:
	var fs: MemorySaveFs = MemorySaveFs.new()
	assert_bool(_store(fs).checkpoint(_world(100), 4)).is_true()
	var res: ResumeResult = _store(fs).try_resume(_factory(), 4)
	assert_int(res.status).is_equal(ResumeResult.Status.DISCARDED_BANKED)
	assert_bool(fs.exists("run_snapshot.sav")).is_false()


func _fake_version(fs: MemorySaveFs) -> void:
	var dec: DecodeResult = SaveCodec.decode(SaveCodec.MAGIC_SNAPSHOT, fs.read("run_snapshot.sav"), 0xFFFF)
	var d: Dictionary = bytes_to_var(dec.raw)
	d["sim_version"] = SimVersion.CURRENT + 1
	fs.files["run_snapshot.sav"] = SaveCodec.encode(SaveCodec.MAGIC_SNAPSHOT, 1, var_to_bytes(d))


func test_version_mismatch_reports_update_with_data_and_deletes() -> void:
	var fs: MemorySaveFs = MemorySaveFs.new()
	var w: SimWorld = _world(2000)
	assert_bool(_store(fs).checkpoint(w, 2)).is_true()
	_fake_version(fs)
	var res: ResumeResult = _store(fs).try_resume(_factory(), 1)
	assert_int(res.status).is_equal(ResumeResult.Status.ENDED_BY_UPDATE)
	assert_str(res.data_run.to_text()).is_equal(w.economy.data_run.to_text())
	assert_bool(fs.exists("run_snapshot.sav")).is_false()


func test_log_lines_carry_tick_and_hash() -> void:
	var fs: MemorySaveFs = MemorySaveFs.new()
	var cp: RunCheckpointer = _store(fs)
	var w: SimWorld = _world(300)
	assert_bool(cp.checkpoint(w, 2)).is_true()
	assert_str(cp.log_lines[0]).contains("[CHECKPOINT] tick=300 hash=" + w.state_hash())


func _mode_factory() -> Callable:
	return func(info: SnapshotInfo) -> SimConfig:
		var cfg: SimConfig = SimConfigLoader.load_default(info.seed_value)
		cfg.best_wave_s1 = info.best_wave_s1
		@warning_ignore("return_value_discarded")  # a mode the data lacks falls back to timed (restore then fails)
		SimConfigLoader.apply_mode(cfg, info.wave_mode)
		return cfg


func _purge_world(ticks: int) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(SEED)
	assert_int(SimConfigLoader.apply_mode(cfg, "purge").size()).is_equal(0)
	var w: SimWorld = SimWorld.new(cfg)
	for i: int in ticks:
		w.step()
	return w


func test_purge_checkpoint_resumes_as_purge() -> void:
	var fs: MemorySaveFs = MemorySaveFs.new()
	var w: SimWorld = _purge_world(1000)
	assert_bool(_store(fs).checkpoint(w, 2)).is_true()
	var res: ResumeResult = _store(fs).try_resume(_mode_factory(), 1)
	assert_int(res.status).is_equal(ResumeResult.Status.RESUMED)
	assert_str(res.info.wave_mode).is_equal("purge")
	assert_str(res.world.config.wave_mode).is_equal("purge")
	assert_str(res.world.state_hash()).is_equal(w.state_hash())


func test_unknown_mode_snapshot_is_banked_as_ended_by_update() -> void:
	var fs: MemorySaveFs = MemorySaveFs.new()
	var w: SimWorld = _purge_world(1500)
	assert_bool(_store(fs).checkpoint(w, 2)).is_true()
	var dec: DecodeResult = SaveCodec.decode(SaveCodec.MAGIC_SNAPSHOT, fs.read("run_snapshot.sav"), 0xFFFF)
	var d: Dictionary = bytes_to_var(dec.raw)
	d["mode"] = "gauntlet"  # not in data/wave_modes.csv: the loader falls back to timed, restore fails
	fs.files["run_snapshot.sav"] = SaveCodec.encode(SaveCodec.MAGIC_SNAPSHOT, 1, var_to_bytes(d))
	var res: ResumeResult = _store(fs).try_resume(_mode_factory(), 1)
	assert_int(res.status).is_equal(ResumeResult.Status.ENDED_BY_UPDATE)
	assert_str(res.data_run.to_text()).is_equal(w.economy.data_run.to_text())
	assert_bool(fs.exists("run_snapshot.sav")).is_false()


func test_simversion_2_purge_snapshot_is_banked_as_ended_by_update() -> void:
	var fs: MemorySaveFs = MemorySaveFs.new()
	var w: SimWorld = _purge_world(1500)
	assert_bool(_store(fs).checkpoint(w, 2)).is_true()
	var dec: DecodeResult = SaveCodec.decode(SaveCodec.MAGIC_SNAPSHOT, fs.read("run_snapshot.sav"), 0xFFFF)
	var d: Dictionary = bytes_to_var(dec.raw)
	d["sim_version"] = 2
	fs.files["run_snapshot.sav"] = SaveCodec.encode(SaveCodec.MAGIC_SNAPSHOT, 1, var_to_bytes(d))
	var res: ResumeResult = _store(fs).try_resume(_mode_factory(), 1)
	assert_int(res.status).is_equal(ResumeResult.Status.ENDED_BY_UPDATE)
	assert_str(res.data_run.to_text()).is_equal(w.economy.data_run.to_text())
	assert_bool(fs.exists("run_snapshot.sav")).is_false()
