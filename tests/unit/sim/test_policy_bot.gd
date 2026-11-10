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
		@warning_ignore("return_value_discarded")  # a draft takes the first offer (M4-15)
		PolicyBot.settle_draft(w)
		w.step()


func test_with_20_scrap_buys_a_greedy4_row_first() -> void:
	var w: SimWorld = _world(0)
	w.economy.scrap = BigNum.from_float(20.0)  # the SimVersion 2 start scrap is 60: pin the old 20-scrap case
	PolicyBot.new("greedy4").think(w)
	assert_int(w.input_log.size()).is_equal(1)
	# With nano_repair at step 0.6 (SimVersion 2) the bot values repair above laser at 20 scrap: any greedy4 row.
	assert_bool(PolicyBot.GREEDY4_IDS.has(w.config.upgrades[w.input_log.arg_a[0]].id)).is_true()
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


func test_cheapest_buys_the_row_with_the_cheapest_next_level() -> void:
	var w: SimWorld = _world(0)
	var cheapest: float = INF
	var cheapest_row: int = -1
	for i: int in w.config.upgrades.size():
		var p: UpgradePreview = UpgradeSystem.preview(w, i, 1)
		if p.visible and not p.maxed and p.cost.to_float() < cheapest:
			cheapest = p.cost.to_float()
			cheapest_row = i
	w.economy.scrap = BigNum.from_float(cheapest)
	PolicyBot.new("cheapest").think(w)
	assert_int(w.input_log.size()).is_greater_equal(1)
	assert_int(w.input_log.arg_a[0]).is_equal(cheapest_row)


func test_cheapest_waits_when_nothing_is_affordable() -> void:
	var w: SimWorld = _world(0)
	w.economy.scrap = BigNum.zero()
	PolicyBot.new("cheapest").think(w)
	assert_int(w.input_log.size()).is_equal(0)


func test_random_policy_is_deterministic_and_only_buys_visible_rows() -> void:
	var a: SimWorld = _world(0)
	_run(a, "random", 4000)
	var b: SimWorld = _world(0)
	_run(b, "random", 4000)
	assert_str(a.state_hash()).is_equal(b.state_hash())
	assert_int(a.input_log.size()).is_greater(3)
	for i: int in a.input_log.size():
		assert_int(a.visible[a.input_log.arg_a[i]]).is_equal(1)


func test_random_and_cheapest_policies_are_accepted_by_the_tools() -> void:
	assert_str(BalanceRunArgs.parse(PackedStringArray(["--policy", "random"])).error).is_empty()
	assert_str(BalanceRunArgs.parse(PackedStringArray(["--policy", "cheapest"])).error).is_empty()
	assert_str(JourneyArgs.parse(PackedStringArray(["--run-policy", "random"])).error).is_empty()
