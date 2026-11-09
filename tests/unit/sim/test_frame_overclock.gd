class_name TestFrameOverclock
extends GdUnitTestSuite
## Overclock: each kill +1% fire rate for the rest of the wave, cap +20% (M3-22).


func _world(frame: bool = true, seed_value: int = 3) -> SimWorld:
	if not frame:
		return SimWorld.new(SimConfigLoader.load_default(seed_value))
	var m: FrameMods = FrameMods.new()
	m.passive = FrameMods.PASSIVE_OVERCLOCK
	return SimWorld.new(TestFrameMods.cfg_with("striker", m, seed_value))


## Puts one enemy in range with 1 hp and fires the laser until it dies.
func _kill_one(w: SimWorld) -> void:
	var i: int = w.debug_spawn_enemy(0, 2.0, 0.0)
	w.enemies.hp[i] = 0.001
	w.grid.rebuild(w.enemies)
	w.laser_charge = w.config.tuning.tick_rate * LaserSystem.CHARGE_UNIT
	LaserSystem.step(w)
	assert_bool(w.enemies.is_alive(i)).is_false()


func test_kills_add_one_percent_each_and_cap_at_twenty() -> void:
	var w: SimWorld = _world()
	for k: int in 5:
		_kill_one(w)
	assert_int(w.overclock_kills).is_equal(5)
	w.laser_charge = 0
	LaserSystem.step(w)
	var base: int = roundi(w.stats.cycle_rate * float(LaserSystem.CHARGE_UNIT))
	assert_int(w.laser_charge).is_equal(base + floori(float(base * 5) / 100.0))
	for k: int in 20:
		_kill_one(w)
	assert_int(w.overclock_kills).is_equal(FrameMods.OVERCLOCK_CAP)
	w.laser_charge = 0
	LaserSystem.step(w)
	assert_int(w.laser_charge).is_equal(base + floori(float(base * 20) / 100.0))


func test_counter_resets_at_wave_end_and_not_without_the_passive() -> void:
	var w: SimWorld = _world()
	_kill_one(w)
	assert_int(w.overclock_kills).is_equal(1)
	WaveEndSystem.step(w)
	assert_int(w.overclock_kills).is_equal(0)
	var plain: SimWorld = _world(false)
	_kill_one(plain)
	assert_int(plain.overclock_kills).is_equal(0)


func test_counter_hashed_only_for_a_non_neutral_frame() -> void:
	var w: SimWorld = _world()
	var before: String = w.state_hash()
	w.overclock_kills = 3
	assert_str(w.state_hash()).is_not_equal(before)
	var plain: SimWorld = _world(false)
	var h: String = plain.state_hash()
	plain.overclock_kills = 3
	assert_str(plain.state_hash()).is_equal(h)


func test_same_seed_and_inputs_give_identical_hashes() -> void:
	var a: SimWorld = _world()
	var b: SimWorld = _world()
	for k: int in 2500:
		if k % 60 == 0:
			@warning_ignore("return_value_discarded")
			a.command_buy(k % 4, 1)
			@warning_ignore("return_value_discarded")
			b.command_buy(k % 4, 1)
		a.step()
		b.step()
	assert_str(a.state_hash()).is_equal(b.state_hash())


func test_per_kill_and_cap_are_data_driven() -> void:
	var m: FrameMods = FrameMods.new()
	m.passive = FrameMods.PASSIVE_OVERCLOCK
	m.overclock_per_kill = 0.02
	m.overclock_cap = 0.10
	assert_int(m.overclock_kill_cap()).is_equal(5)
	var w: SimWorld = SimWorld.new(TestFrameMods.cfg_with("striker", m, 3))
	for k: int in 9:
		_kill_one(w)
	assert_int(w.overclock_kills).is_equal(5)
	w.laser_charge = 0
	LaserSystem.step(w)
	var base: int = roundi(w.stats.cycle_rate * float(LaserSystem.CHARGE_UNIT))
	assert_int(w.laser_charge).is_equal(base + floori(float(base * 5 * 2) / 100.0))


func test_defaults_equal_the_old_constants() -> void:
	var m: FrameMods = FrameMods.new()
	assert_float(m.bastion_cap_frac).is_equal(0.20)
	assert_float(m.overclock_per_kill).is_equal(0.01)
	assert_float(m.overclock_cap).is_equal(0.20)
	assert_int(m.overclock_kill_cap()).is_equal(FrameMods.OVERCLOCK_CAP)
	assert_int(m.overclock_scale()).is_equal(1000)
