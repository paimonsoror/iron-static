class_name TestSimWorld
extends GdUnitTestSuite
## SimWorld skeleton: wave clock, events, intake pipeline, hash, spawn helper.


func _cfg(seed_value: int = 1) -> SimConfig:
	var cfg: SimConfig = SimConfigLoader.load_default(seed_value)
	cfg.debug_invulnerable = true
	return cfg


func _buf(events_n: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(out.resize(events_n * SimEvents.FIELDS)).is_equal(OK)
	return out


func _count_kind(w: SimWorld, kind: int, a: int) -> int:
	var out: PackedInt32Array = _buf(SimEvents.CAPACITY)
	var n: int = w.events.drain(0, out)
	var c: int = 0
	for k: int in n:
		if out[k * 4 + 1] == kind and out[k * 4 + 2] == a:
			c += 1
	return c


func test_wave_clock_rolls_over_after_720_ticks() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	for i: int in 720:
		w.step()
	assert_int(w.wave).is_equal(2)
	assert_int(w.wave_tick).is_equal(0)
	assert_int(w.tick).is_equal(720)
	assert_int(_count_kind(w, SimEventKind.WAVE_STARTED, 1)).is_equal(1)
	assert_int(_count_kind(w, SimEventKind.WAVE_STARTED, 2)).is_equal(1)
	# Other systems (spawns, shots) also push events now, so only WAVE_STARTED is counted.
	assert_int(_count_kind(w, SimEventKind.WAVE_STARTED, 3)).is_equal(0)


func test_levels_start_with_sector_offset() -> void:
	var cfg: SimConfig = _cfg()
	assert_int(SimWorld.new(cfg).level_hp).is_equal(1)
	cfg.sector = 3
	var w: SimWorld = SimWorld.new(cfg)
	assert_int(w.level_hp).is_equal(1 + 25 * 2)
	assert_int(w.level_atk).is_equal(51)


func test_apply_hit_plating_and_floor() -> void:
	var cfg: SimConfig = _cfg()
	var c: CinderState = CinderState.new()
	c.setup(100.0, false)
	var s: StatBlock = StatBlock.new()
	s.plating_pct = 0.5
	s.plating_flat = 1.0
	assert_float(c.apply_hit(10.0, s, cfg.tuning)).is_equal_approx(4.0, 0.0001)
	assert_float(c.hp).is_equal_approx(96.0, 0.0001)
	s.plating_pct = 0.0
	s.plating_flat = 100.0
	assert_float(c.apply_hit(10.0, s, cfg.tuning)).is_equal_approx(0.5, 0.0001)
	s.plating_pct = 0.99  # capped at plating_pct_cap (0.9)
	s.plating_flat = 0.0
	assert_float(c.apply_hit(10.0, s, cfg.tuning)).is_equal_approx(1.0, 0.0001)


func test_death_ends_run_and_freezes_hash() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	var w: SimWorld = SimWorld.new(cfg)
	w.step()
	assert_bool(w.is_over()).is_false()
	var hit: float = w.cinder.apply_hit(1000000.0, w.stats, cfg.tuning)
	assert_float(hit).is_greater(0.0)
	assert_bool(w.cinder.alive).is_false()
	w.step()
	assert_bool(w.is_over()).is_true()
	assert_int(w.run.death_wave).is_equal(1)
	var h: String = w.state_hash()
	var pushed: int = w.events.total_pushed
	for i: int in 10:
		w.step()
	assert_str(w.state_hash()).is_equal(h)
	assert_int(w.events.total_pushed).is_equal(pushed)
	assert_int(_count_kind(w, SimEventKind.RUN_ENDED, 1)).is_equal(1)
	w.end_run()
	assert_int(_count_kind(w, SimEventKind.RUN_ENDED, 1)).is_equal(1)


func test_invulnerable_never_dies() -> void:
	var cfg: SimConfig = _cfg()
	var w: SimWorld = SimWorld.new(cfg)
	var taken: float = w.cinder.apply_hit(1000000.0, w.stats, cfg.tuning)
	assert_float(taken).is_greater(0.0)
	assert_bool(w.cinder.alive).is_true()
	assert_float(w.cinder.hp).is_equal(0.0)


func test_same_config_same_hash_every_tick() -> void:
	var a: SimWorld = SimWorld.new(_cfg(7))
	var b: SimWorld = SimWorld.new(_cfg(7))
	assert_int(a.debug_spawn_enemy(0, 30.0, 0.0)).is_equal(0)
	assert_int(b.debug_spawn_enemy(0, 30.0, 0.0)).is_equal(0)
	for i: int in 100:
		assert_str(a.state_hash()).is_equal(b.state_hash())
		a.step()
		b.step()
	assert_str(a.state_hash()).is_equal(b.state_hash())


func test_different_seeds_different_hash() -> void:
	var a: SimWorld = SimWorld.new(_cfg(1))
	var b: SimWorld = SimWorld.new(_cfg(2))
	var spawned: int = a.debug_spawn_enemy(0, 30.0, 0.0)
	spawned += b.debug_spawn_enemy(0, 30.0, 0.0)
	assert_int(spawned).is_equal(0)
	assert_str(a.state_hash()).is_not_equal(b.state_hash())


func test_hash_length_and_sensitivity() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	var h0: String = w.state_hash()
	assert_int(h0.length()).is_equal(64)
	assert_str(h0).is_equal(h0.to_lower())
	var i: int = w.debug_spawn_enemy(0, 30.0, 0.0)
	var h1: String = w.state_hash()
	assert_str(h1).is_not_equal(h0)
	w.enemies.hp[i] -= 1.0
	assert_str(w.state_hash()).is_not_equal(h1)
	var h2: String = w.state_hash()
	w.laser_charge += 1
	assert_str(w.state_hash()).is_not_equal(h2)


func test_spawn_enemy_fields() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	var i: int = w.spawn_enemy(0, 52.0, 0.0)
	assert_int(i).is_equal(0)
	assert_float(w.enemies.hp[i]).is_equal_approx(14.0, 0.0001)
	assert_float(w.enemies.dmg[i]).is_equal_approx(2.0, 0.0001)
	assert_float(w.enemies.speed[i]).is_equal_approx(3.5, 0.0001)
	assert_float(w.enemies.radius[i]).is_equal_approx(0.6, 0.0001)
	assert_float(w.enemies.prev_x[i]).is_equal(52.0)
	assert_int(w.enemies.born_wave[i]).is_equal(1)
	assert_int(w.enemies.level_hp[i]).is_equal(1)
	assert_int(_count_kind(w, SimEventKind.ENEMY_SPAWNED, i)).is_equal(1)
	var walker: int = w.spawn_enemy(2, 0.0, 52.0)
	assert_float(w.enemies.hp[walker]).is_equal_approx(70.0, 0.0001)
	assert_float(w.enemies.dmg[walker]).is_equal_approx(3.0, 0.0001)
	w.level_hp = 11
	var later: int = w.spawn_enemy(0, 1.0, 1.0)
	assert_float(w.enemies.hp[later]).is_equal_approx(14.0 * pow(1.063, 10.0), 0.001)
	assert_int(w.enemies.level_hp[later]).is_equal(11)


func test_type_tables_and_counts() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	assert_int(w.type_behavior[3]).is_equal(SimWorld.BEH_RANGED)
	assert_int(w.type_behavior[4]).is_equal(SimWorld.BEH_MELEE_BOSS)
	var first: int = w.spawn_enemy(0, 1.0, 0.0)
	assert_int(w.type_is_boss[4]).is_equal(1)
	first += w.spawn_enemy(4, 2.0, 0.0)
	assert_int(first).is_equal(1)
	assert_int(w.alive_boss_count()).is_equal(1)
	assert_int(w.alive_normal_count()).is_equal(1)
	assert_bool(w.is_boss_wave(10)).is_true()
	assert_bool(w.next_wave_is_boss).is_false()


func test_debug_spawn_bolt_and_full_store() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	var i: int = w.debug_spawn_bolt(10.0, 0.0, -18.0, 0.0, 5.0)
	assert_int(i).is_equal(0)
	assert_float(w.projectiles.damage[i]).is_equal(5.0)
	assert_int(w.projectiles.ttl_ticks[i]).is_equal(ceili(52.0 / 18.0 * 30.0) + 30)
	for k: int in w.projectiles.capacity - 1:
		assert_int(w.debug_spawn_bolt(0.0, 0.0, 0.0, 0.0, 1.0)).is_greater_equal(0)
	assert_int(w.debug_spawn_bolt(0.0, 0.0, 0.0, 0.0, 1.0)).is_equal(-1)


func test_events_ring_wraps_and_reports_loss() -> void:
	var ev: SimEvents = SimEvents.new()
	var out: PackedInt32Array = _buf(64)
	for k: int in 3000:
		ev.tick = k
		ev.push(SimEventKind.ENEMY_HIT, k, 1)
	var cur: int = ev.drain(0, out)
	assert_int(ev.last_drain_lost).is_equal(3000 - SimEvents.CAPACITY)
	assert_int(cur).is_equal(3000 - SimEvents.CAPACITY + 64)
	assert_int(out[2]).is_equal(3000 - SimEvents.CAPACITY)
	while cur < ev.total_pushed:
		cur = ev.drain(cur, out)
	assert_int(ev.last_drain_lost).is_equal(0)
	assert_int(cur).is_equal(3000)
	assert_int(ev.drain(cur, out)).is_equal(cur)


func test_stat_block_from_base() -> void:
	var s: StatBlock = StatBlock.from_base(_cfg())
	assert_float(s.laser_output).is_equal(10.0)
	assert_float(s.cycle_rate).is_equal(1.0)
	assert_float(s.crit_chance).is_equal_approx(0.02, 0.00001)
	assert_float(s.crit_mult).is_equal(1.5)
	assert_float(s.optic_range).is_equal(24.0)
	assert_float(s.hull_integrity).is_equal(100.0)
	assert_float(s.nano_repair).is_equal(1.0)
	assert_float(s.plating_pct).is_equal(0.0)
	assert_float(s.plating_flat).is_equal(0.0)
