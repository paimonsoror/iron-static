class_name TestLaserSystem
extends GdUnitTestSuite
## LaserSystem, DamagePipeline, kills and rewards.

const SKITTER: int = 0


func _world() -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.debug_invulnerable = true
	return SimWorld.new(cfg)


## Spawns an immortal-ish target at (x, y).
func _tank(w: SimWorld, x: float, y: float) -> int:
	var i: int = w.debug_spawn_enemy(SKITTER, x, y)
	w.enemies.hp[i] = 1.0e12
	return i


func _run(w: SimWorld, ticks: int) -> void:
	for k: int in ticks:
		w.grid.rebuild(w.enemies)
		LaserSystem.step(w)


func _shots(w: SimWorld) -> int:
	return roundi(w.run.damage_dealt / w.stats.laser_output)


func _events_of(w: SimWorld, kind: int) -> Array[Vector2i]:
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(out.resize(SimEvents.CAPACITY * SimEvents.FIELDS)).is_equal(OK)
	var n: int = w.events.drain(0, out)
	var res: Array[Vector2i] = []
	for k: int in n:
		if out[k * SimEvents.FIELDS + 1] == kind:
			res.append(Vector2i(out[k * SimEvents.FIELDS + 2], out[k * SimEvents.FIELDS + 3]))
	return res


func test_cycle_rate_1_fires_one_shot_per_30_ticks() -> void:
	var w: SimWorld = _world()
	w.stats.cycle_rate = 1.0
	assert_int(_tank(w, 10.0, 0.0)).is_greater_equal(0)
	_run(w, 29)
	assert_int(_shots(w)).is_equal(0)
	_run(w, 1)
	assert_int(_shots(w)).is_equal(1)
	_run(w, 270)
	assert_int(_shots(w)).is_equal(10)


func test_cycle_rate_1_04_fires_104_in_3000_ticks() -> void:
	var w: SimWorld = _world()
	w.stats.cycle_rate = 1.04
	assert_int(_tank(w, 10.0, 0.0)).is_greater_equal(0)
	_run(w, 3000)
	assert_int(_shots(w)).is_between(103, 105)


func test_skitter_dies_on_second_hit_and_pays() -> void:
	var w: SimWorld = _world()
	w.stats.cycle_rate = 1.0
	w.stats.crit_chance = 0.0
	var i: int = w.debug_spawn_enemy(SKITTER, 10.0, 0.0)
	assert_float(w.enemies.hp[i]).is_equal_approx(14.0, 0.0001)
	_run(w, 30)
	assert_bool(w.enemies.is_alive(i)).is_true()
	assert_int(w.run.kills).is_equal(0)
	_run(w, 30)
	assert_bool(w.enemies.is_alive(i)).is_false()
	assert_int(w.run.kills).is_equal(1)
	assert_int(w.run.kills_by_type[SKITTER]).is_equal(1)
	assert_float(w.run.scrap_earned).is_equal_approx(2.0, 0.0001)
	assert_float(w.run.data_earned).is_equal_approx(1.04, 0.0001)
	assert_int(_events_of(w, SimEventKind.ENEMY_KILLED).size()).is_equal(1)


func test_stale_enemy_pays_half() -> void:
	var w: SimWorld = _world()
	w.stats.cycle_rate = 1.0
	w.stats.crit_chance = 0.0
	var i: int = w.debug_spawn_enemy(SKITTER, 10.0, 0.0)
	w.enemies.stale[i] = 1
	_run(w, 60)
	assert_int(w.run.kills).is_equal(1)
	assert_float(w.run.scrap_earned).is_equal_approx(1.0, 0.0001)
	assert_float(w.run.data_earned).is_equal_approx(0.52, 0.0001)


func test_equal_distance_hits_lower_spawn_id_first() -> void:
	var w: SimWorld = _world()
	w.stats.cycle_rate = 1.0
	var a: int = _tank(w, 10.0, 0.0)
	var b: int = _tank(w, -10.0, 0.0)
	_run(w, 30)
	assert_float(w.enemies.hp[a]).is_less(1.0e12)
	assert_float(w.enemies.hp[b]).is_equal(1.0e12)
	# Whichever spawned first has the lower spawn_id; swap roles to prove it is not index order.
	var w2: SimWorld = _world()
	w2.stats.cycle_rate = 1.0
	var c: int = _tank(w2, 10.0, 0.0)
	var d: int = _tank(w2, -10.0, 0.0)
	w2.enemies.release(c)
	var c2: int = _tank(w2, 10.0, 0.0)
	assert_int(c2).is_equal(c)
	assert_int(w2.enemies.spawn_id[c2]).is_greater(w2.enemies.spawn_id[d])
	_run(w2, 30)
	assert_float(w2.enemies.hp[d]).is_less(1.0e12)
	assert_float(w2.enemies.hp[c2]).is_equal(1.0e12)


func test_out_of_range_not_hit_until_in_range() -> void:
	var w: SimWorld = _world()
	w.stats.cycle_rate = 1.0
	w.stats.optic_range = 24.0
	var i: int = _tank(w, 30.0, 0.0)
	_run(w, 90)
	assert_float(w.run.damage_dealt).is_equal(0.0)
	assert_int(w.laser_charge).is_equal(30000)
	w.enemies.pos_x[i] = 20.0
	_run(w, 1)
	assert_float(w.run.damage_dealt).is_greater(0.0)


func test_charge_capped_at_one_shot_without_target() -> void:
	var w: SimWorld = _world()
	w.stats.cycle_rate = 2.0
	_run(w, 100)
	assert_int(w.laser_charge).is_equal(30000)
	assert_int(_tank(w, 10.0, 0.0)).is_greater_equal(0)
	_run(w, 1)
	assert_int(_shots(w)).is_equal(1)


func test_crit_rate_matches_chance() -> void:
	var rng: Rng = Rng.new(99, 3)
	var stats: StatBlock = StatBlock.new()
	stats.laser_output = 10.0
	stats.crit_chance = 0.02
	stats.crit_mult = 1.5
	var out: PackedInt32Array = PackedInt32Array([0])
	var crits: int = 0
	var shots: int = 20000
	for k: int in shots:
		var dmg: int = DamagePipeline.laser_damage(stats, rng, out)
		crits += out[0]
		assert_int(dmg).is_equal(15 if out[0] == 1 else 10)
	assert_float(float(crits) / float(shots)).is_between(0.015, 0.025)


func test_crit_flag_in_shot_event() -> void:
	var w: SimWorld = _world()
	w.stats.cycle_rate = 1.0
	w.stats.crit_chance = 1.0
	w.stats.crit_mult = 2.0
	var i: int = _tank(w, 10.0, 0.0)
	_run(w, 30)
	var shots: Array[Vector2i] = _events_of(w, SimEventKind.SHOT_FIRED)
	assert_array(shots).is_equal([Vector2i(i, 1)])
	var hits: Array[Vector2i] = _events_of(w, SimEventKind.ENEMY_HIT)
	assert_array(hits).is_equal([Vector2i(i, 20)])


func test_damage_floor_is_one() -> void:
	var w: SimWorld = _world()
	w.stats.laser_output = 0.4
	w.stats.crit_chance = 0.0
	w.stats.cycle_rate = 1.0
	var i: int = _tank(w, 10.0, 0.0)
	_run(w, 30)
	assert_float(w.enemies.hp[i]).is_equal_approx(1.0e12 - 1.0, 1.0e6)
	assert_float(w.run.damage_dealt).is_equal(1.0)


func test_multiple_shots_in_one_tick_retarget() -> void:
	var w: SimWorld = _world()
	w.stats.cycle_rate = 3.0
	w.stats.crit_chance = 0.0
	w.stats.laser_output = 100.0
	var near: int = w.debug_spawn_enemy(SKITTER, 5.0, 0.0)
	var far: int = w.debug_spawn_enemy(SKITTER, 15.0, 0.0)
	w.laser_charge = 60000
	_run(w, 1)
	# charge 60000 + 3000 = 63000: two shots; the first kills `near`, the second must hit `far`.
	assert_bool(w.enemies.is_alive(near)).is_false()
	assert_bool(w.enemies.is_alive(far)).is_false()
	assert_int(w.run.kills).is_equal(2)
