class_name TestResumeHashPath
extends GdUnitTestSuite
## A run killed mid-wave resumes from its last checkpoint with the identical hash path (M3-13 acceptance).

const SEED: int = 4
const RUN_ID: int = 3
const CHECK_EVERY: int = 900
const KILL_TICK: int = 2450
const MAX_TICKS: int = 60000
const WATCH: Array[int] = [2000, KILL_TICK]
const FOUNDRY: Dictionary = {"laser_output": 3, "hull_integrity": 2}


func _cfg(foundry: Dictionary) -> SimConfig:
	var cfg: SimConfig = SimConfigLoader.load_default(SEED)
	SimConfigLoader.apply_foundry(cfg, foundry)
	return cfg


## Scripted buys: a pure function of the tick, so the resumed run repeats them exactly.
func _step(w: SimWorld) -> void:
	if w.tick % 45 == 0:
		@warning_ignore("return_value_discarded")
		w.command_buy(floori(float(w.tick) / 45.0) % 4, 1)
	w.step()


## Hashes at the watch ticks and at the death tick: "tick:hash" strings.
func _path(w: SimWorld, from_tick: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var guard: int = 0
	while not w.is_over() and guard < MAX_TICKS:
		_step(w)
		guard += 1
		if WATCH.has(w.tick) and w.tick > from_tick:
			out.append("%d:%s" % [w.tick, w.state_hash()])
	out.append("death@%d:%s" % [w.tick, w.state_hash()])
	return out


func _factory(foundry: Dictionary) -> Callable:
	return func(info: SnapshotInfo) -> SimConfig:
		var cfg: SimConfig = SimConfigLoader.load_default(info.seed_value)
		cfg.best_wave_s1 = info.best_wave_s1
		SimConfigLoader.apply_foundry(cfg, foundry)
		return cfg


func _check(foundry: Dictionary) -> void:
	var reference: PackedStringArray = _path(SimWorld.new(_cfg(foundry)), -1)
	var fs: MemorySaveFs = MemorySaveFs.new()
	var cp: RunCheckpointer = RunCheckpointer.new(RunCheckpointer.make_store(fs))
	var live: SimWorld = SimWorld.new(_cfg(foundry))
	while live.tick < KILL_TICK:
		if live.tick > 0 and live.tick % CHECK_EVERY == 0:
			assert_bool(cp.checkpoint(live, RUN_ID)).is_true()
		_step(live)
	# kill: discard the world and the checkpointer, keep only the files
	var cp2: RunCheckpointer = RunCheckpointer.new(RunCheckpointer.make_store(fs))
	var res: ResumeResult = cp2.try_resume(_factory(foundry), 2)
	assert_int(res.status).is_equal(ResumeResult.Status.RESUMED)
	assert_int(res.world.tick).is_equal(1800)
	assert_int(res.info.run_id).is_equal(RUN_ID)
	var resumed: PackedStringArray = _path(res.world, 1800)
	# the resumed run covers 2000, 2450 and the death tick; the reference has the same entries
	assert_array(resumed).is_equal(reference)
	for line: String in resumed:
		print("[HASHPATH] foundry=%d %s" % [foundry.size(), line])
	# [CHECKPOINT] at 1800 and [RESUME] carry the same hash
	var cp_line: String = ""
	var rs_line: String = ""
	for l: String in cp.log_lines:
		if l.contains("tick=1800 "):
			cp_line = l
	for l2: String in cp2.log_lines:
		if l2.begins_with("[RESUME]"):
			rs_line = l2
	assert_str(cp_line).is_not_empty()
	assert_str(cp_line.split("hash=")[1].split(" ")[0]).is_equal(rs_line.split("hash=")[1])


func test_resume_follows_identical_hash_path() -> void:
	_check({})


func test_resume_follows_identical_hash_path_with_foundry() -> void:
	_check(FOUNDRY)
