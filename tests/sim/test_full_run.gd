class_name TestFullRun
extends GdUnitTestSuite
## Default config, no upgrades, seed 1, played until Cinder dies (M1-15 item 3).

const MAX_TICKS: int = 60000
const DEATH_WAVE_MIN: int = 3
const DEATH_WAVE_MAX: int = 12


func _play(seed_value: int) -> SimWorld:
	var w: SimWorld = SimWorld.new(SimConfigLoader.load_default(seed_value))
	while not w.is_over() and w.tick < MAX_TICKS:
		@warning_ignore("return_value_discarded")  # a draft takes the first offer (M4-15)
		PolicyBot.settle_draft(w)
		w.step()
	return w


func test_seed_1_dies_in_gdd_window() -> void:
	var w: SimWorld = _play(1)
	assert_bool(w.is_over()).is_true()
	assert_int(w.tick).is_less(MAX_TICKS)
	assert_int(w.run.death_wave).is_between(DEATH_WAVE_MIN, DEATH_WAVE_MAX)
	assert_int(w.run.kills).is_greater(0)
	assert_bool(is_finite(w.run.scrap_earned) and is_finite(w.run.data_earned)).is_true()
	assert_bool(is_finite(w.run.damage_dealt) and is_finite(w.cinder.hp)).is_true()
	assert_float(w.run.scrap_earned).is_greater(0.0)


func test_hash_stable_across_two_executions() -> void:
	var a: SimWorld = _play(1)
	var b: SimWorld = _play(1)
	assert_str(a.state_hash()).is_equal(b.state_hash())
	assert_int(a.run.death_wave).is_equal(b.run.death_wave)


func test_other_seeds_also_end_with_finite_rewards() -> void:
	for s: int in [2, 3, 4]:
		var w: SimWorld = _play(s)
		assert_bool(w.is_over()).is_true()
		assert_bool(is_finite(w.run.scrap_earned) and is_finite(w.run.data_earned)).is_true()


func _play_purge(seed_value: int) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(seed_value)
	assert_int(SimConfigLoader.apply_mode(cfg, "purge").size()).is_equal(0)
	assert_int(cfg.purge_backstop_ticks).is_equal(1800)
	var w: SimWorld = SimWorld.new(cfg)
	while not w.is_over() and w.tick < MAX_TICKS:
		@warning_ignore("return_value_discarded")  # a draft takes the first offer (M4-15)
		PolicyBot.settle_draft(w)
		w.step()
	return w


func test_purge_run_ends_with_finite_rewards_and_is_repeatable() -> void:
	var a: SimWorld = _play_purge(1)
	assert_bool(a.is_over()).is_true()
	assert_int(a.tick).is_less(MAX_TICKS)
	assert_int(a.run.death_wave).is_greater(0)
	assert_int(a.run.kills).is_greater(0)
	assert_bool(is_finite(a.run.scrap_earned) and is_finite(a.run.data_earned)).is_true()
	assert_bool(is_finite(a.run.damage_dealt) and is_finite(a.cinder.hp)).is_true()
	assert_float(a.run.scrap_earned).is_greater(0.0)
	assert_str(_play_purge(1).state_hash()).is_equal(a.state_hash())


## M4-17: the wave-10 boss can be killed. Cinder is not invulnerable; the boss is brought down to 1 hp next to the
## laser so the kill path (events, kill count, rewards) is what is under test.
func test_boss_hulk_can_be_killed_at_wave_10() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(3)
	cfg.debug_invulnerable = false
	var w := SimWorld.new(cfg)
	w.wave = 10
	var boss_type: int = -1
	for i: int in cfg.enemies.size():
		if w.type_is_boss[i] != 0:
			boss_type = i
	var boss: int = -1
	var guard: int = 0
	while boss < 0 and guard < 200:
		w.step()
		guard += 1
		for i: int in w.enemies.high_water:
			if w.enemies.alive[i] != 0 and w.enemies.type_id[i] == boss_type:
				boss = i
	assert_int(boss).is_greater_equal(0)
	assert_int(w.alive_boss_count()).is_equal(1)
	var scrap_before: float = w.run.scrap_earned
	var data_before: float = w.run.data_earned
	w.enemies.hp[boss] = 1.0
	w.enemies.pos_x[boss] = 2.0
	w.enemies.pos_y[boss] = 0.0
	w.enemies.prev_x[boss] = 2.0
	w.enemies.prev_y[boss] = 0.0
	var steps: int = 0
	while w.alive_boss_count() > 0 and steps < 90 and not w.is_over():
		w.step()
		steps += 1
	assert_int(w.alive_boss_count()).is_equal(0)
	assert_int(w.run.kills_by_type[boss_type]).is_equal(1)
	assert_float(w.run.scrap_earned).is_greater(scrap_before)
	assert_float(w.run.data_earned).is_greater(data_before)
	assert_bool(w.is_over()).is_false()
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(out.resize(SimEvents.CAPACITY * SimEvents.FIELDS)).is_equal(OK)
	var n: int = w.events.drain(0, out)
	var killed: int = 0
	for k: int in n:
		if out[k * 4 + 1] == SimEventKind.ENEMY_KILLED and out[k * 4 + 3] == boss_type:
			killed += 1
	assert_int(killed).is_equal(1)
