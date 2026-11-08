class_name TestSpawnSystem
extends GdUnitTestSuite
## SpawnSystem and WavePlanner (M1-08): plan content, timing, angles, boss waves, alive caps.

const BOSS: int = 4


func _world(seed_value: int = 7, cap_normal: int = -1) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(seed_value)
	cfg.debug_invulnerable = true
	if cap_normal >= 0:
		cfg.tuning.alive_cap_normal = cap_normal
	return SimWorld.new(cfg)


## Builds the plan for `w` directly; returns the number of grouped entries.
func _build(world: SimWorld, w: int) -> int:
	world.plan.begin(w)
	return WavePlanner.build(world)


func _slots(world: SimWorld, include_boss: bool = false) -> int:
	var total: int = 0
	for i: int in world.plan.count:
		var ty: int = world.plan.type_index[i]
		if ty == BOSS and not include_boss:
			continue
		total += world.config.enemies[ty].slots
	return total


func _count_of(world: SimWorld, type_index: int) -> int:
	var n: int = 0
	for i: int in world.plan.count:
		if world.plan.type_index[i] == type_index:
			n += 1
	return n


func test_wave_1_has_8_skitters() -> void:
	var w: SimWorld = _world()
	_build_plan(w, 1)
	assert_int(w.plan.count).is_equal(8)
	assert_int(_count_of(w, 0)).is_equal(8)
	assert_bool(w.plan.built).is_true()


func test_no_darts_in_waves_1_to_3() -> void:
	var w: SimWorld = _world()
	for wave: int in range(1, 4):
		_build_plan(w, wave)
		assert_int(_count_of(w, 1)).is_equal(0)


func test_slots_per_wave_match_n_of_w() -> void:
	var w: SimWorld = _world()
	var t: SimTuning = w.config.tuning
	for wave: int in range(4, 61):
		_build_plan(w, wave)
		var n: int = Curves.slots_for_wave(wave, t.n_base, t.n_coef, t.n_exp, t.n_cap)
		if w.is_boss_wave(wave):
			n = floori(t.boss_slot_fraction * float(n))
		var s: int = _slots(w)
		assert_int(s).is_between(n, n + t.slot_overflow)


func test_types_appear_only_from_first_wave() -> void:
	var w: SimWorld = _world()
	var lancers_from_6: int = 0
	var walkers_from_8: int = 0
	for wave: int in range(1, 61):
		_build_plan(w, wave)
		if wave < 4:
			assert_int(_count_of(w, 1)).is_equal(0)
		if wave < 6:
			assert_int(_count_of(w, 3)).is_equal(0)
		else:
			lancers_from_6 += _count_of(w, 3)
		if wave < 8:
			assert_int(_count_of(w, 2)).is_equal(0)
		else:
			walkers_from_8 += _count_of(w, 2)
		if not w.is_boss_wave(wave):
			assert_int(_count_of(w, BOSS)).is_equal(0)
	assert_int(lancers_from_6).is_greater(0)
	assert_int(walkers_from_8).is_greater(0)


func test_boss_wave_plan() -> void:
	var w: SimWorld = _world()
	var t: SimTuning = w.config.tuning
	for wave: int in [10, 20, 30]:
		_build_plan(w, wave)
		var n: int = Curves.slots_for_wave(wave, t.n_base, t.n_coef, t.n_exp, t.n_cap)
		assert_int(_count_of(w, BOSS)).is_equal(1)
		assert_int(_slots(w)).is_between(floori(0.6 * float(n)), floori(0.6 * float(n)) + t.slot_overflow)
		for i: int in w.plan.count:
			if w.plan.type_index[i] == BOSS:
				assert_int(w.plan.spawn_tick[i]).is_equal(60)
	_build_plan(w, 10)
	assert_int(_slots(w)).is_between(9, 11)


func test_boss_spawns_at_tick_60_with_event() -> void:
	var w: SimWorld = _world()
	w.wave = 10
	w.plan.begin(10)
	var boss_tick: int = -1
	for wt: int in 120:
		w.wave_tick = wt
		SpawnSystem.step(w)
		if boss_tick < 0 and w.enemies.count_type(BOSS) > 0:
			boss_tick = wt
	assert_int(boss_tick).is_equal(60)
	assert_int(w.enemies.count_type(BOSS)).is_equal(1)
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(out.resize(SimEvents.CAPACITY * SimEvents.FIELDS)).is_equal(OK)
	var n: int = w.events.drain(0, out)
	var bosses: int = 0
	for k: int in n:
		if out[k * 4 + 1] == SimEventKind.BOSS_SPAWNED:
			bosses += 1
	assert_int(bosses).is_equal(1)


func test_spawn_ticks_sorted_and_in_range() -> void:
	var w: SimWorld = _world()
	for wave: int in range(1, 101):
		_build_plan(w, wave)
		for i: int in w.plan.count:
			var tk: int = w.plan.spawn_tick[i]
			assert_int(tk).is_between(0, Ticks.SPAWN_TICKS - 1)
			if i > 0:
				assert_int(tk).is_greater_equal(w.plan.spawn_tick[i - 1])
			assert_int(w.plan.angle_idx[i]).is_between(0, SinCosTable.SIZE - 1)


func test_flank_fraction_about_40_percent() -> void:
	var w: SimWorld = _world(11)
	var grouped: int = 0
	var total: int = 0
	for wave: int in range(1, 2001):
		grouped += _build(w, wave)
		total += w.plan.count
	var frac: float = float(grouped) / float(total)
	assert_float(frac).is_between(0.35, 0.45)


func test_same_seed_same_plan_different_seed_differs() -> void:
	var a: SimWorld = _world(5)
	var b: SimWorld = _world(5)
	var c: SimWorld = _world(6)
	_build_plan(a, 30)
	_build_plan(b, 30)
	_build_plan(c, 30)
	assert_int(a.plan.count).is_equal(b.plan.count)
	var differs: bool = a.plan.count != c.plan.count
	for i: int in a.plan.count:
		assert_int(a.plan.type_index[i]).is_equal(b.plan.type_index[i])
		assert_int(a.plan.spawn_tick[i]).is_equal(b.plan.spawn_tick[i])
		assert_int(a.plan.angle_idx[i]).is_equal(b.plan.angle_idx[i])
		if a.plan.count == c.plan.count and a.plan.angle_idx[i] != c.plan.angle_idx[i]:
			differs = true
	assert_bool(differs).is_true()


func test_spawn_positions_on_arena_rim() -> void:
	var w: SimWorld = _world()
	for wt: int in Ticks.SPAWN_TICKS:
		w.wave_tick = wt
		SpawnSystem.step(w)
	assert_int(w.enemies.alive_count).is_equal(8)
	for i: int in w.enemies.high_water:
		var r: float = Vector2(w.enemies.pos_x[i], w.enemies.pos_y[i]).length()
		assert_float(r).is_equal_approx(w.config.tuning.arena_radius, 0.01)


func test_alive_cap_throttles_but_never_drops() -> void:
	var w: SimWorld = _world(3, 5)
	w.wave = 12
	w.plan.begin(12)
	var max_alive: int = 0
	for wt: int in Ticks.WAVE_TICKS:
		w.wave_tick = wt
		SpawnSystem.step(w)
		max_alive = maxi(max_alive, w.alive_normal_count())
		if wt % 200 == 199:  # simulate kills
			for i: int in w.enemies.high_water:
				w.enemies.release(i)
	assert_int(max_alive).is_equal(5)
	assert_int(w.plan.cursor).is_equal(w.plan.count)
	assert_int(w.plan.count).is_greater(5)
	for i: int in w.plan.count:
		assert_int(w.plan.spawned[i]).is_equal(1)
	assert_int(w.run.spawn_throttled).is_greater(0)


func test_carry_over_spawns_every_planned_enemy_across_waves() -> void:
	var w: SimWorld = _world(9, 1)
	var planned: int = 0
	var spawned: int = 0
	var carried_seen: int = 0
	for wave: int in range(1, 9):
		w.wave = wave
		w.plan.begin(wave, true)
		for wt: int in Ticks.WAVE_TICKS:
			w.wave_tick = wt
			SpawnSystem.step(w)
			if wt == 0:
				planned += w.plan.count - w.plan.carried
				carried_seen += w.plan.carried
			if wt % 100 == 99:  # simulate kills
				spawned += w.enemies.alive_count
				for i: int in w.enemies.high_water:
					w.enemies.release(i)
	assert_int(carried_seen).is_greater(0)
	# Drain: no new plan, keep killing; every leftover entry must still spawn.
	for wt: int in range(Ticks.WAVE_TICKS, Ticks.WAVE_TICKS * 6):
		w.wave_tick = Ticks.WAVE_TICKS - 1
		SpawnSystem.step(w)
		if wt % 5 == 0:
			spawned += w.enemies.alive_count
			for i: int in w.enemies.high_water:
				w.enemies.release(i)
	assert_int(w.plan.cursor).is_equal(w.plan.count)
	assert_int(spawned).is_equal(planned)
	assert_int(w.plan.dropped_carry).is_equal(0)
	assert_int(w.plan.dropped_slots).is_equal(0)


func test_carry_over_entries_lead_the_next_plan_and_are_hashed() -> void:
	var w: SimWorld = _world(4, 0)
	w.plan.begin(1)
	WavePlanner.build(w)
	var first_count: int = w.plan.count
	var before: String = w.state_hash()
	w.plan.begin(2, true)
	assert_int(w.plan.carried).is_equal(first_count)
	WavePlanner.build(w)
	assert_int(w.plan.count).is_greater(first_count)
	for i: int in first_count:
		assert_int(w.plan.spawn_tick[i]).is_equal(0)
	assert_str(w.state_hash()).is_not_equal(before)


func test_carry_bound_counts_dropped_entries() -> void:
	var w: SimWorld = _world(4, 0)
	w.plan.begin(1)
	WavePlanner.build(w)
	var limit: int = w.plan.capacity() >> 1
	w.plan.count = limit + 5
	for i: int in w.plan.count:
		w.plan.spawned[i] = 0
	w.plan.cursor = 0
	w.plan.begin(2, true)
	assert_int(w.plan.carried).is_equal(limit)
	assert_int(w.plan.dropped_carry).is_equal(5)


func test_stepping_world_spawns_wave_1() -> void:
	var w: SimWorld = _world()
	for i: int in Ticks.WAVE_TICKS - 1:
		w.step()
	assert_int(w.plan.count).is_equal(8)
	assert_int(w.plan.cursor).is_equal(8)


@warning_ignore("return_value_discarded")  # grouped count not needed here
func _build_plan(world: SimWorld, w: int) -> void:
	world.plan.begin(w)
	WavePlanner.build(world)
