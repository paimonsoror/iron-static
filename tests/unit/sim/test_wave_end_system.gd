class_name TestWaveEndSystem
extends GdUnitTestSuite
## WaveEndSystem: level increment, WAVE_ENDED, stale marking, boss flag; RewardCalc stale payout.

const SKITTER: int = 0


func _world() -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.debug_invulnerable = true
	return SimWorld.new(cfg)


func _drain(w: SimWorld) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(out.resize(SimEvents.CAPACITY * SimEvents.FIELDS)).is_equal(OK)
	var n: int = w.events.drain(0, out)
	var res: PackedInt32Array = PackedInt32Array()
	assert_int(res.resize(n * SimEvents.FIELDS)).is_equal(OK)
	for k: int in n * SimEvents.FIELDS:
		res[k] = out[k]
	return res


func test_levels_after_10_wave_ends() -> void:
	var w: SimWorld = _world()
	for k: int in 10:
		WaveEndSystem.step(w)
		w.wave += 1
	assert_int(w.level_hp).is_equal(11)
	assert_int(w.level_atk).is_equal(11)


func test_wave_ended_events_carry_wave_number() -> void:
	var w: SimWorld = _world()
	for k: int in 3:
		WaveEndSystem.step(w)
		w.wave += 1
	var ev: PackedInt32Array = _drain(w)
	var waves: Array[int] = []
	for k: int in ev.size() >> 2:
		if ev[k * SimEvents.FIELDS + 1] == SimEventKind.WAVE_ENDED:
			waves.append(ev[k * SimEvents.FIELDS + 2])
	assert_array(waves).is_equal([1, 2, 3])


func test_stale_marking_on_third_wave_end() -> void:
	var w: SimWorld = _world()
	w.wave = 3
	var old: int = w.debug_spawn_enemy(SKITTER, 40.0, 0.0)
	w.wave = 5
	var young: int = w.debug_spawn_enemy(SKITTER, 40.0, 1.0)
	for ending: int in [3, 4]:
		w.wave = ending
		WaveEndSystem.step(w)
		assert_int(w.enemies.stale[old]).is_equal(0)
	w.wave = 5
	WaveEndSystem.step(w)
	assert_int(w.enemies.stale[old]).is_equal(1)
	assert_int(w.enemies.stale[young]).is_equal(0)
	w.wave = 6
	WaveEndSystem.step(w)
	assert_int(w.enemies.stale[young]).is_equal(0)
	w.wave = 7
	WaveEndSystem.step(w)
	assert_int(w.enemies.stale[young]).is_equal(1)


func test_next_wave_is_boss_flag() -> void:
	var w: SimWorld = _world()
	assert_bool(w.next_wave_is_boss).is_false()
	# Ending wave 8: the world moves to wave 9, so the next wave after that is 10 (boss).
	w.wave = 8
	WaveEndSystem.step(w)
	assert_bool(w.next_wave_is_boss).is_true()
	w.wave = 9
	WaveEndSystem.step(w)
	assert_bool(w.next_wave_is_boss).is_false()


func test_reward_calc_stale_pays_half() -> void:
	var w: SimWorld = _world()
	var t: SimTuning = w.config.tuning
	var def: EnemyDef = w.config.enemies[SKITTER]
	assert_float(RewardCalc.scrap_for_kill(t, def, 1, 1.0, false)).is_equal_approx(2.0, 0.0001)
	assert_float(RewardCalc.scrap_for_kill(t, def, 1, 1.0, true)).is_equal_approx(1.0, 0.0001)
	assert_float(RewardCalc.data_for_kill(t, def, 1, 1, false)).is_equal_approx(1.04, 0.0001)
	assert_float(RewardCalc.data_for_kill(t, def, 1, 1, true)).is_equal_approx(0.52, 0.0001)
	assert_float(RewardCalc.data_for_kill(t, def, 1, 2, false)).is_equal_approx(1.04 * t.reward_growth, 0.0001)


func test_300_ticks_with_no_enemies_stays_consistent() -> void:
	var w: SimWorld = _world()
	for k: int in 300:
		w.step()
	assert_int(w.wave).is_equal(1)
	assert_int(w.wave_tick).is_equal(300)
	assert_int(w.level_hp).is_equal(1)
	assert_bool(w.is_over()).is_false()
