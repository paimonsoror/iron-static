class_name TestGameState
extends GdUnitTestSuite
## RunController state machine (M1-23): BOOT -> IN_RUN -> RESULTS -> redeploy, pause, debug load mode.

const MAX_TICKS: int = 60000
const GAME_SCRIPT: String = "res://src/core/game.gd"


func test_starts_in_boot_without_world() -> void:
	var c := RunController.new()
	assert_int(c.state).is_equal(RunController.State.BOOT)
	assert_object(c.world).is_null()
	assert_int(c.update(0.1)).is_equal(0)


func test_start_run_enters_in_run_with_seed() -> void:
	var c := RunController.new()
	var started: Array[int] = []
	c.run_started.connect(func(_w: SimWorld) -> void: started.append(1))
	c.start_run(RunController.DEFAULT_SEED)
	assert_int(c.state).is_equal(RunController.State.IN_RUN)
	assert_int(c.seed_value).is_equal(1)
	assert_object(c.world).is_not_null()
	assert_int(started.size()).is_equal(1)


func test_death_goes_to_results_then_redeploy_uses_next_seed() -> void:
	var c := RunController.new()
	var ended: Array[int] = []
	c.run_ended.connect(func(_w: SimWorld) -> void: ended.append(1))
	c.start_run(1)
	var first: SimWorld = c.world
	var ran: int = c.fast_forward(MAX_TICKS)
	assert_int(ran).is_greater(0)
	assert_int(c.state).is_equal(RunController.State.RESULTS)
	assert_bool(first.is_over()).is_true()
	assert_int(ended.size()).is_equal(1)
	assert_int(first.run.death_wave).is_greater(0)
	assert_int(c.update(0.5)).is_equal(0)  # RESULTS does not advance
	c.redeploy()
	assert_int(c.state).is_equal(RunController.State.IN_RUN)
	assert_int(c.seed_value).is_equal(2)
	assert_bool(c.world != first).is_true()
	assert_int(c.world.tick).is_equal(0)
	assert_bool(c.world.is_over()).is_false()
	c.fast_forward(MAX_TICKS)
	assert_int(c.state).is_equal(RunController.State.RESULTS)
	assert_str(c.world.state_hash()).is_not_equal(first.state_hash())
	assert_int(ended.size()).is_equal(2)


func test_update_advances_and_pause_stops() -> void:
	var c := RunController.new()
	c.start_run(1)
	var ran: int = c.update(SimWorld.DT * 3.0 + 0.001)
	assert_int(ran).is_greater(0)
	assert_int(c.world.tick).is_equal(ran)
	c.paused = true
	var tick: int = c.world.tick
	assert_int(c.update(1.0)).is_equal(0)
	assert_int(c.world.tick).is_equal(tick)
	c.paused = false
	c.speed = 2
	assert_int(c.update(SimWorld.DT)).is_greater(0)


func test_update_detects_death_and_results() -> void:
	var c := RunController.new()
	c.start_run(1)
	c.driver.budget_usec = 1000000
	var guard: int = 0
	while c.state == RunController.State.IN_RUN and guard < MAX_TICKS:
		c.update(SimWorld.DT * 4.0)
		guard += 1
	assert_int(c.state).is_equal(RunController.State.RESULTS)
	assert_bool(c.world.is_over()).is_true()


func test_debug_load_fast_forwards_invulnerable_then_continues() -> void:
	var c := RunController.new()
	var finished: Array[int] = []
	c.load_finished.connect(func(_w: SimWorld) -> void: finished.append(1))
	c.start_run(1, true, 4)
	assert_int(c.load_wave).is_equal(4)
	assert_float(c.load_progress()).is_less(1.0)
	var guard: int = 0
	while c.load_wave > 0 and guard < 100000:
		c.update(SimWorld.DT)
		guard += 1
	assert_int(c.load_wave).is_equal(0)
	assert_int(c.world.wave).is_greater_equal(4)
	assert_int(c.state).is_equal(RunController.State.IN_RUN)
	assert_int(finished.size()).is_equal(1)
	assert_float(c.load_progress()).is_equal(1.0)
	var tick: int = c.world.tick
	c.update(SimWorld.DT * 2.0)
	assert_int(c.world.tick).is_greater(tick)  # continues normally


func test_redeploy_after_load_is_a_normal_run() -> void:
	var c := RunController.new()
	c.start_run(1, true, 2)
	c.redeploy()
	assert_int(c.load_wave).is_equal(0)
	assert_bool(c.world.config.debug_invulnerable).is_false()
	assert_int(c.seed_value).is_equal(2)


func test_time_text_and_cause_text() -> void:
	assert_str(RunController.time_text(0)).is_equal("00:00")
	assert_str(RunController.time_text(30 * 75)).is_equal("01:15")
	assert_str(RunController.time_text(-5)).is_equal("00:00")
	var c := RunController.new()
	c.start_run(1)
	c.world.run.death_cause = -1
	assert_str(RunController.cause_text(c.world)).is_equal("UNKNOWN")
	c.world.run.death_cause = 0
	assert_str(RunController.cause_text(c.world)).is_equal("SKITTER")


func test_start_run_with_mode_builds_a_purge_config() -> void:
	var c := RunController.new()
	var w: SimWorld = c.start_run(1, false, 0, {}, 0, "", SimConfig.MODE_PURGE)
	assert_str(w.config.wave_mode).is_equal("purge")
	assert_int(w.config.purge_backstop_ticks).is_greater(0)
	assert_str(c.start_run(1).config.wave_mode).is_equal("timed")
	assert_str(c.start_run(1, false, 0, {}, 0, "", "bogus").config.wave_mode).is_equal("timed")


func _game() -> Node:
	var script: GDScript = load(GAME_SCRIPT)
	var g: Node = script.new()
	g.call("setup_persistence", MemorySaveFs.new(), PackedStringArray())
	return g


func _free_game(g: Node) -> void:
	var a: Node = g.get("audio")
	a.free()
	g.free()


func test_game_start_run_purge_and_redeploy_repeats_the_mode() -> void:
	SaveKey.reset()
	var g: Node = _game()
	var saves: SaveService = g.get("saves")
	var c: RunController = g.get("controller")
	c.last_run_path = "user://runs/test_game_state_run.json"
	@warning_ignore("return_value_discarded")
	saves.profile.unlock_mode("purge")
	g.call("start_run", "purge")
	assert_str(c.world.config.wave_mode).is_equal("purge")
	c.fast_forward(60000)
	assert_str(saves.profile.last_mode).is_equal("timed")  # start_run(mode) does not persist the choice itself
	@warning_ignore("return_value_discarded")
	saves.profile.select_mode("purge")
	g.call("redeploy")
	assert_str(c.world.config.wave_mode).is_equal("purge")
	_free_game(g)


func test_game_start_run_never_uses_a_locked_mode_but_debug_override_does() -> void:
	SaveKey.reset()
	var g: Node = _game()
	var c: RunController = g.get("controller")
	g.call("start_run", "purge")
	assert_str(c.world.config.wave_mode).is_equal("timed")
	g.set("mode_override", "purge")
	g.call("start_run")
	assert_str(c.world.config.wave_mode).is_equal("purge")
	_free_game(g)


func test_mode_arg_parsing_and_resolve_order() -> void:
	var script: GDScript = load(GAME_SCRIPT)
	assert_str(script.call("mode_from_args", PackedStringArray(["--mode", "purge"]))).is_equal("purge")
	assert_str(script.call("mode_from_args", PackedStringArray(["--mode=purge"]))).is_equal("purge")
	assert_str(script.call("mode_from_args", PackedStringArray(["--mode"]))).is_equal("")
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	assert_str(RunMode.resolve(p, "purge", "")).is_equal("timed")
	assert_str(RunMode.resolve(p, "", "purge")).is_equal("purge")
	@warning_ignore("return_value_discarded")
	p.unlock_mode("purge")
	@warning_ignore("return_value_discarded")
	p.select_mode("purge")
	assert_str(RunMode.resolve(p, "", "")).is_equal("purge")
	assert_str(RunMode.resolve(p, "timed", "")).is_equal("timed")


func test_purge_death_does_not_raise_the_session_timed_best() -> void:
	var c := RunController.new()
	@warning_ignore("return_value_discarded")
	c.start_run(1, false, 0, {}, 0, "", "purge")
	@warning_ignore("return_value_discarded")
	c.fast_forward(MAX_TICKS)
	assert_int(c.state).is_equal(RunController.State.RESULTS)
	assert_int(c.best_wave_s1).is_equal(0)  # Q71: PURGE gates nothing
	@warning_ignore("return_value_discarded")
	c.start_run(1)
	@warning_ignore("return_value_discarded")
	c.fast_forward(MAX_TICKS)
	assert_int(c.best_wave_s1).is_greater(0)
