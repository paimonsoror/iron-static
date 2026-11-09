class_name TestPolicyNone
extends GdUnitTestSuite
## `--policy none` (M3-24): the idle scenario never buys, so the input log stays empty and only the
## starting stats matter; `BalanceRunArgs.buys` is the switch the runner reads.


func test_none_does_not_buy() -> void:
	assert_bool(BalanceRunArgs.buys("none")).is_false()
	assert_bool(BalanceRunArgs.buys("greedy4")).is_true()
	assert_bool(BalanceRunArgs.buys("all")).is_true()


func test_idle_run_has_no_purchases_and_is_deterministic() -> void:
	var hashes: PackedStringArray = PackedStringArray()
	for _pass: int in 2:
		var world: SimWorld = SimWorld.new(BalanceSetup.make_config(7, 1, 0, {}, "vanguard"))
		while not world.is_over() and world.wave <= 30:
			@warning_ignore("return_value_discarded")  # a draft takes the first offer (M4-15)
			PolicyBot.settle_draft(world)
			world.step()
		assert_int(world.input_log.size()).is_equal(0)
		assert_bool(hashes.append(world.state_hash())).is_false()
	assert_str(hashes[0]).is_equal(hashes[1])


func test_greedy_buys_where_none_does_not() -> void:
	var world: SimWorld = SimWorld.new(BalanceSetup.make_config(7, 1, 0, {}, "vanguard"))
	var bot: PolicyBot = PolicyBot.new("greedy4")
	while not world.is_over() and world.wave <= 5:
		if world.tick % PolicyBot.THINK_INTERVAL == 0:
			bot.think(world)
		@warning_ignore("return_value_discarded")  # a draft takes the first offer (M4-15)
		PolicyBot.settle_draft(world)
		world.step()
	assert_int(world.input_log.size()).is_greater(0)
