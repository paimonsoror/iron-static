class_name TestPolicyBot
extends GdUnitTestSuite
## PolicyBot greedy buyer (M2-13).

const TICKS: int = 10000


func _world(best_wave: int, seed_value: int = 4) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(seed_value)
	cfg.best_wave_s1 = best_wave
	cfg.debug_invulnerable = true
	return SimWorld.new(cfg)


func _run(w: SimWorld, policy: String, ticks: int) -> void:
	var bot: PolicyBot = PolicyBot.new(policy)
	while not w.is_over() and w.tick < ticks:
		if w.tick % PolicyBot.THINK_INTERVAL == 0:
			bot.think(w)
		w.step()


func test_with_20_scrap_buys_laser_output_first() -> void:
	var w: SimWorld = _world(0)
	PolicyBot.new("greedy4").think(w)
	assert_int(w.input_log.size()).is_equal(1)
	assert_str(w.config.upgrades[w.input_log.arg_a[0]].id).is_equal("laser_output")
	assert_int(w.run_levels[w.input_log.arg_a[0]]).is_equal(1)


func test_waits_when_best_row_is_unaffordable() -> void:
	var w: SimWorld = _world(0)
	w.economy.scrap = BigNum.from_float(5.0)
	PolicyBot.new("greedy4").think(w)
	assert_int(w.input_log.size()).is_equal(0)


func test_run_is_deterministic_and_replays() -> void:
	var a: SimWorld = _world(0)
	_run(a, "greedy4", TICKS)
	var b: SimWorld = _world(0)
	_run(b, "greedy4", TICKS)
	assert_str(a.state_hash()).is_equal(b.state_hash())
	assert_int(a.input_log.size()).is_greater(5)
	var rec: RunRecord = RunRecord.from_world(a)
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	assert_str(Replay.run(cfg, rec, TICKS)).is_equal(a.state_hash())


func test_greedy4_never_buys_a_locked_or_unlisted_row() -> void:
	for best_wave: int in [0, 100]:
		var w: SimWorld = _world(best_wave)
		_run(w, "greedy4", 4000)
		for i: int in w.input_log.size():
			var row: int = w.input_log.arg_a[i]
			assert_int(w.visible[row]).is_equal(1)
			assert_bool(PolicyBot.GREEDY4_IDS.has(w.config.upgrades[row].id)).is_true()


func test_all_policy_only_buys_visible_rows() -> void:
	var w: SimWorld = _world(3)
	_run(w, "all", 4000)
	assert_int(w.input_log.size()).is_greater(0)
	for i: int in w.input_log.size():
		assert_int(w.visible[w.input_log.arg_a[i]]).is_equal(1)
