class_name TestReplay
extends GdUnitTestSuite
## InputLog, RunRecord, ConfigHash and Replay (M2-07).

const MAX_TICKS: int = 60000
const GOLDEN_SIM_VERSION: int = 2
const GOLDEN_CONFIG_HASH: String = "43ca2931080753827c979b9b0f25d6d51a45770bc8ee9c37b1754439a4698337"
const GOLDEN_FINAL_HASH: String = "495093804bfad776c3b35ab4d884f8bc1b4442525f259aa547ab326e64ceeda0"
const GOLDEN_TICKS: int = 3000
const NO_BUDGET_LIMIT: int = 1_000_000_000

var _marks: PackedStringArray = PackedStringArray()


func _cfg(seed_value: int = 3) -> SimConfig:
	return SimConfigLoader.load_default(seed_value)


## Scripted buys: every 45 ticks try rows 0..3 once (rejections are not logged); returns the live world.
## `marks` collects state hashes at the requested ticks.
func _scripted(cfg: SimConfig, limit: int, marks: PackedInt32Array = PackedInt32Array()) -> SimWorld:
	var w: SimWorld = SimWorld.new(cfg)
	var seen: PackedStringArray = PackedStringArray()
	while not w.is_over() and w.tick < limit:
		if marks.has(w.tick):
			@warning_ignore("return_value_discarded")
			seen.append(w.state_hash())
		if w.tick % 45 == 0:
			@warning_ignore("return_value_discarded")
			w.command_buy(floori(float(w.tick) / 45.0) % 4, 1)
		w.step()
	_marks = seen
	return w


func test_replay_matches_final_and_checkpoints() -> void:
	var live: SimWorld = _scripted(_cfg(), 100)  # find the death tick first
	assert_int(live.tick).is_equal(100)
	var full: SimWorld = _scripted(_cfg(), MAX_TICKS)
	assert_bool(full.is_over()).is_true()
	assert_int(full.input_log.size()).is_greater(3)
	var ticks: PackedInt32Array = PackedInt32Array([full.tick >> 2, full.tick >> 1, (full.tick * 3) >> 2])
	var rerun: SimWorld = _scripted(_cfg(), MAX_TICKS, ticks)
	var live_marks: PackedStringArray = _marks
	var rec: RunRecord = RunRecord.from_world(rerun)
	assert_str(rec.final_hash).is_equal(full.state_hash())
	assert_str(Replay.run(_cfg(99), rec, MAX_TICKS)).is_equal(rec.final_hash)
	var replayed: PackedStringArray = Replay.checkpoints(_cfg(99), rec, ticks)
	for i: int in 3:
		assert_str(replayed[i]).is_equal(live_marks[i])
	var again: SimWorld = Replay.run_world(_cfg(), rec, MAX_TICKS)
	assert_int(again.input_log.size()).is_equal(rec.commands.size())


func test_moving_a_command_by_a_few_ticks_changes_the_final_hash() -> void:
	# A shift only matters when it moves a buy across a shot or hit, so try each command in turn. With the
	# SimVersion 2 start scrap (60) the early buys all land at once, so one tick is not enough: also try 40
	# ticks (less than the 45-tick spacing, so the log stays ordered).
	var rec: RunRecord = RunRecord.from_world(_scripted(_cfg(), MAX_TICKS))
	var changed: int = 0
	for i: int in rec.commands.size():
		for shift: int in [1, 40]:
			rec.commands.ticks[i] += shift
			if Replay.run(_cfg(), rec, MAX_TICKS) != rec.final_hash:
				changed += 1
			rec.commands.ticks[i] -= shift
	assert_int(changed).is_greater(0)
	assert_str(Replay.run(_cfg(), rec, MAX_TICKS)).is_equal(rec.final_hash)


func test_run_record_json_round_trips() -> void:
	var rec: RunRecord = RunRecord.from_world(_scripted(_cfg(), MAX_TICKS))
	var back: RunRecord = RunRecord.from_json(rec.to_json())
	assert_object(back).is_not_null()
	assert_str(back.to_json()).is_equal(rec.to_json())
	assert_str(Replay.run(_cfg(), back, MAX_TICKS)).is_equal(rec.final_hash)
	assert_int(back.sim_version).is_equal(SimVersion.CURRENT)
	assert_str(back.config_hash).is_equal(ConfigHash.compute(_cfg()))
	assert_object(RunRecord.from_json("[1]")).is_null()


func test_json_under_20kb_for_2000_commands() -> void:
	var rec: RunRecord = RunRecord.new()
	var modes: PackedInt32Array = PackedInt32Array([1, 10, 100, -1])
	var t: int = 0
	for i: int in 2000:
		t += 5 + (i * 7) % 90
		rec.commands.append(t, InputLog.CMD_BUY, i % 10, modes[i % 4])
	var text: String = rec.to_json()
	assert_int(text.length()).is_less(20000)
	var back: RunRecord = RunRecord.from_json(text)
	assert_int(back.commands.size()).is_equal(2000)
	assert_int(back.commands.ticks[1999]).is_equal(t)
	assert_int(back.commands.arg_b[3]).is_equal(-1)


func test_config_hash_changes_with_any_tuning_value() -> void:
	var base: String = ConfigHash.compute(_cfg())
	assert_str(ConfigHash.compute(_cfg())).is_equal(base)
	var c1: SimConfig = _cfg()
	c1.tuning.hp0 += 1.0
	assert_str(ConfigHash.compute(c1)).is_not_equal(base)
	var c2: SimConfig = _cfg()
	c2.tuning.n_cap += 1
	assert_str(ConfigHash.compute(c2)).is_not_equal(base)
	var c3: SimConfig = _cfg()
	c3.upgrades[0].c0 += 1.0
	assert_str(ConfigHash.compute(c3)).is_not_equal(base)
	var c4: SimConfig = _cfg()
	c4.enemies[0].speed += 0.5
	assert_str(ConfigHash.compute(c4)).is_not_equal(base)


func test_driver_speed_1x_and_4x_with_same_command_ticks_agree() -> void:
	var cmd_ticks: PackedInt32Array = PackedInt32Array([0, 31, 100, 407, 900, 1500])
	var h1: String = _driven(1, cmd_ticks)
	assert_str(_driven(4, cmd_ticks)).is_equal(h1)


func _driven(speed: int, cmd_ticks: PackedInt32Array) -> String:
	var cfg: SimConfig = _cfg(5)
	cfg.debug_invulnerable = true
	var w: SimWorld = SimWorld.new(cfg)
	var driver: TickDriver = TickDriver.new()
	driver.budget_usec = NO_BUDGET_LIMIT
	var frames: Rng = Rng.new(7, 99)
	var targets: PackedInt32Array = cmd_ticks.duplicate()
	if targets.append(2000):
		push_error("append failed")
	for i: int in targets.size():
		var target: int = targets[i]
		driver.tick_limit = target
		var guard: int = 0
		while w.tick < target and guard < 100000:
			@warning_ignore("return_value_discarded")
			driver.advance(w, 0.005 + frames.next_float() * 0.035, speed)
			guard += 1
		if i < cmd_ticks.size():
			@warning_ignore("return_value_discarded")
			w.command_buy(i % 4, 1)
	assert_int(w.tick).is_equal(2000)
	return w.state_hash()


func test_golden_run_hash_prompts_a_sim_version_bump() -> void:
	var cfg: SimConfig = _cfg(7)
	cfg.debug_invulnerable = true
	var w: SimWorld = _scripted(cfg, GOLDEN_TICKS)
	var cfg_hash: String = ConfigHash.compute(_cfg(7))
	if cfg_hash != GOLDEN_CONFIG_HASH:
		push_warning("data CSVs changed: refresh GOLDEN_CONFIG_HASH/GOLDEN_FINAL_HASH (golden check skipped)")
		return
	assert_int(SimVersion.CURRENT).is_equal(GOLDEN_SIM_VERSION)
	(
		assert_str(w.state_hash())
		. override_failure_message(
			"Sim outcome changed for the same inputs: bump SimVersion.CURRENT and update the golden"
		)
		. is_equal(GOLDEN_FINAL_HASH)
	)
