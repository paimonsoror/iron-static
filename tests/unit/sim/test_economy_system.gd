class_name TestEconomySystem
extends GdUnitTestSuite
## EconomySystem: start scrap, kill rewards, scrap_yield, reinvest cap, BigNum conversion rate (M2-05).

const SKITTER: int = 0


func _world() -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.debug_invulnerable = true
	return SimWorld.new(cfg)


func _row(w: SimWorld, id: String) -> int:
	for i: int in w.config.upgrades.size():
		if w.config.upgrades[i].id == id:
			return i
	return -1


## Kills one skitter at point blank with one laser shot (hp 1) and applies the economy stage.
func _kill_skitter(w: SimWorld, stale: bool) -> void:
	var i: int = w.debug_spawn_enemy(SKITTER, 5.0, 0.0)
	w.enemies.hp[i] = 1.0
	w.enemies.stale[i] = 1 if stale else 0
	w.laser_charge = 30000
	w.grid.rebuild(w.enemies)
	LaserSystem.step(w)
	EconomySystem.apply_tick(w)


func test_start_scrap_is_60() -> void:
	var w: SimWorld = _world()
	assert_float(w.economy.scrap.to_float()).is_equal_approx(60.0, 1.0e-6)
	assert_bool(w.economy.data_run.is_zero()).is_true()


func test_wave1_skitter_pays_2_scrap_and_1_04_data() -> void:
	var w: SimWorld = _world()
	_kill_skitter(w, false)
	assert_float(w.economy.scrap.to_float()).is_equal_approx(62.0, 1.0e-6)
	assert_float(w.economy.data_run.to_float()).is_equal_approx(1.04, 1.0e-9)
	assert_float(w.economy.wave_kill_scrap).is_equal_approx(2.0, 1.0e-9)


func test_scrap_yield_level_10_floors_with_carry() -> void:
	var w: SimWorld = _world()
	w.run_levels[_row(w, "scrap_yield")] = 10
	w.stats = StatBlock.from_resolver(w.config.upgrades, w.run_levels)
	assert_float(w.stats.scrap_yield).is_equal_approx(1.2, 1.0e-9)
	_kill_skitter(w, false)
	assert_float(w.economy.scrap.to_float()).is_equal_approx(62.0, 1.0e-6)  # 2.4 floored
	assert_float(w.economy.scrap_frac).is_equal_approx(0.4, 1.0e-9)
	for k: int in 2:
		_kill_skitter(w, false)
	# 3 kills = 7.2: 7 whole scrap added, 0.2 carried
	assert_float(w.economy.scrap.to_float()).is_equal_approx(67.0, 1.0e-6)


func test_stale_kill_pays_half() -> void:
	var w: SimWorld = _world()
	_kill_skitter(w, true)
	assert_float(w.economy.scrap.to_float()).is_equal_approx(61.0, 1.0e-6)
	assert_float(w.economy.data_run.to_float()).is_equal_approx(0.52, 1.0e-9)


func test_reinvest_payout_capped_by_half_wave_kill_scrap() -> void:
	var w: SimWorld = _world()
	w.economy.scrap = BigNum.from_int(1000)
	w.stats.reinvest = 0.0594
	w.economy.wave_kill_scrap = 10.0
	EconomySystem.wave_end(w)
	assert_float(w.economy.scrap.to_float()).is_equal_approx(1005.0, 1.0e-6)
	assert_float(w.economy.wave_kill_scrap).is_equal(0.0)


func test_reinvest_below_cap_pays_floor_of_rate() -> void:
	var w: SimWorld = _world()
	w.economy.scrap = BigNum.from_int(1000)
	w.stats.reinvest = 0.0594
	w.economy.wave_kill_scrap = 1000.0
	EconomySystem.wave_end(w)
	assert_float(w.economy.scrap.to_float()).is_equal_approx(1059.0, 1.0e-6)


func test_no_interest_without_reinvest() -> void:
	var w: SimWorld = _world()
	w.economy.wave_kill_scrap = 100.0
	EconomySystem.wave_end(w)
	assert_float(w.economy.scrap.to_float()).is_equal_approx(60.0, 1.0e-6)


func test_3000_tick_run_matches_float_shadow_and_converts_once_per_tick() -> void:
	var w: SimWorld = _world()
	var ticks_with_kills: int = 0
	for k: int in 3000:
		var before: int = w.economy.conversions
		if k % 3 == 0 and w.alive_normal_count() < 5:
			var i: int = w.debug_spawn_enemy(SKITTER, 4.0, 0.0)
			w.enemies.hp[i] = 1.0
		w.step()
		assert_int(w.economy.conversions - before).is_less_equal(1)
		if w.economy.conversions > before:
			ticks_with_kills += 1
	assert_int(ticks_with_kills).is_greater(50)
	var total: float = w.economy.scrap.to_float() + w.economy.scrap_frac
	var shadow: float = 60.0 + w.run.scrap_earned
	assert_float(absf(total - shadow) / shadow).is_less(1.0e-9)
	var data_shadow: float = w.run.data_earned
	assert_float(absf(w.economy.data_run.to_float() - data_shadow) / data_shadow).is_less(1.0e-9)
	assert_float(w.tick_scrap).is_equal(0.0)


func test_economy_in_state_hash() -> void:
	var a: SimWorld = _world()
	var b: SimWorld = _world()
	assert_str(a.state_hash()).is_equal(b.state_hash())
	b.economy.scrap = BigNum.from_int(21)
	assert_str(a.state_hash()).is_not_equal(b.state_hash())
