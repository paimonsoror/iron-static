class_name TestFxSpawner
extends GdUnitTestSuite
## Event -> effect mapping, rate limiting, pool bounds and sim-time behaviour of FxSpawner (V1-13).

var _world: SimWorld
var _enemies: EnemyRenderer
var _ring: ParticleRenderer
var _fx: FxSpawner


func before_test() -> void:
	_world = SimWorld.new(SimConfigLoader.load_default(1))
	_enemies = auto_free(EnemyRenderer.new())
	add_child(_enemies)
	_enemies.setup(33.75, PackedFloat32Array([0.6, 0.5, 1.4, 0.7, 3.0]), EnemyStore.DEFAULT_CAPACITY, 32, 2.0)
	_ring = auto_free(ParticleRenderer.new())
	add_child(_ring)
	_ring.setup(400)
	_fx = FxSpawner.new()
	_fx.setup(_ring, _enemies)
	_world.tick = 100
	_fx.update(_world, 0.0, null, 0)  # binds the cursor


func _spawn(type_index: int, dist: float = 8.0) -> int:
	var i: int = _world.enemies.alloc(type_index)
	_world.enemies.pos_x[i] = dist
	_world.enemies.prev_x[i] = dist
	_world.enemies.radius[i] = 0.5
	return i


func _written() -> int:
	return _ring.additive.total_written + _ring.smoke.total_written


func _step(alpha: float = 0.0, band: int = 0) -> void:
	_world.tick += 1
	_fx.update(_world, alpha, null, band)


func test_kill_event_spawns_the_recipe_count_at_the_enemy() -> void:
	var i: int = _spawn(0)
	_world.enemies.release(i)
	_world.events.push(SimEventKind.ENEMY_KILLED, i, 0)
	var before: int = _written()
	_step()
	assert_int(_written() - before).is_equal(FxRecipes.kill_total(0, _world.enemies.alive_count, true))
	var p: Vector2 = _ring.additive.pos_at(0)
	var expect: Vector2 = _enemies.draw_pos(_world.enemies, i, 0.0)
	assert_float(p.distance_to(expect)).is_less(1.0)
	assert_int(_fx.kills_spawned).is_equal(1)


func test_walker_and_boss_bursts_are_bigger() -> void:
	var counts := PackedInt32Array()
	for t: int in [0, 2, 4]:
		var i: int = _spawn(t)
		_world.enemies.release(i)
		_world.events.push(SimEventKind.ENEMY_KILLED, i, t)
		var before: int = _written()
		_step()
		assert_bool(counts.append(_written() - before)).is_false()
	assert_int(counts[1]).is_greater(counts[0])
	assert_int(counts[2]).is_greater(counts[1])
	assert_int(counts[2]).is_less_equal(120)
	assert_int(_fx.boss_kills).is_equal(1)


func test_thousand_kills_in_one_frame_stay_bounded_and_do_not_allocate() -> void:
	var idx: int = _spawn(0)
	_world.enemies.release(idx)
	var resize_before: int = _fx.resize_count
	var buf_before: int = _ring.additive.buffer.size() + _ring.smoke.buffer.size()
	for k: int in 1000:
		_world.events.push(SimEventKind.ENEMY_KILLED, idx, k % 4)
	_step()
	assert_int(_ring.live_count()).is_less_equal(400)
	assert_int(_ring.additive.used).is_less_equal(_ring.additive.capacity)
	assert_int(_ring.additive.buffer.size() + _ring.smoke.buffer.size()).is_equal(buf_before)
	assert_int(_fx.resize_count).is_equal(resize_before)
	assert_int(_fx.kills_dropped).is_greater(900)
	assert_int(_written()).is_less_equal(FxRecipes.particle_budget(0) + 20)


func test_hits_are_rate_limited_per_frame_and_per_enemy() -> void:
	var ids: Array[int] = []
	for k: int in 40:
		ids.append(_spawn(k % 3, 5.0 + float(k) * 0.2))
	for k: int in 40:
		_world.events.push(SimEventKind.ENEMY_HIT, ids[k], 5)
	_step()
	assert_int(_fx.hits_spawned).is_less_equal(FxRecipes.hit_budget(0))
	assert_int(_fx.hits_spawned).is_greater(0)
	assert_int(_fx.hits_dropped).is_greater(30)
	# the same enemy again on the next tick (33 ms later, inside the 50 ms cooldown): skipped
	var spawned: int = _fx.hits_spawned
	_world.events.push(SimEventKind.ENEMY_HIT, ids[0], 5)
	_step()
	assert_int(_fx.hits_spawned).is_equal(spawned)


func test_hit_spawns_an_impact_with_nine_particles() -> void:
	var i: int = _spawn(1)
	_world.events.push(SimEventKind.ENEMY_HIT, i, 5)
	var before: int = _written()
	_step()
	assert_int(_written() - before).is_equal(FxRecipes.impact_total(6, 1, false, true))
	assert_int(FxRecipes.impact_total(6, 1, false, true)).is_equal(9)


func test_band_change_worse_spawns_ring_flakes_and_embers() -> void:
	_world.events.push(SimEventKind.BAND_CHANGED, 0, 1)
	var before: int = _written()
	_step()
	var wedges: int = (FxRecipes.BAND_WEDGES[1] as Array).size()
	var expect: int = 2 + wedges * (1 + FxRecipes.EMBERS_PER_WEDGE)
	assert_int(_written() - before).is_equal(expect)
	assert_int(_fx.band_worse_count).is_equal(1)
	# going up spawns only the small teal ring
	_world.events.push(SimEventKind.BAND_CHANGED, 1, 0)
	before = _written()
	_step()
	assert_int(_written() - before).is_equal(1)


func test_cinder_hit_spawns_four_sparks_and_records_damage() -> void:
	_world.events.push(SimEventKind.CINDER_HIT, 7, 0)
	var before: int = _written()
	_step()
	assert_int(_written() - before).is_equal(FxRecipes.CINDER_HIT_SPARKS)
	assert_int(_fx.cinder_hits).is_equal(1)
	assert_int(_fx.last_cinder_damage).is_equal(7)


func test_embers_follow_the_band_rate_in_sim_time() -> void:
	var written_by_band := PackedInt32Array()
	for band: int in 4:
		var before: int = _written()
		for k: int in 30:  # one sim second
			_step(0.0, band)
		assert_bool(written_by_band.append(_written() - before)).is_false()
	assert_int(written_by_band[0]).is_equal(0)
	assert_int(written_by_band[1]).is_between(2, 4)
	assert_int(written_by_band[2]).is_between(7, 9)
	assert_int(written_by_band[3]).is_between(13, 15)


func test_pause_freezes_time_and_speed_scales_it() -> void:
	_fx.update(_world, 0.5, null, 0)
	var t0: float = _ring.now()
	_fx.update(_world, 0.5, null, 0)  # paused: same tick and alpha
	assert_float(_ring.now()).is_equal(t0)
	for k: int in 4:  # 4x speed: four ticks in one frame
		_world.tick += 1
	_fx.update(_world, 0.5, null, 0)
	assert_float(_ring.now() - t0).is_equal_approx(4.0 * SimWorld.DT, 0.0001)


func test_reduce_motion_removes_rings_but_keeps_flashes() -> void:
	var visual := VisualSettings.new()
	visual.reduce_motion = true
	var i: int = _spawn(2)
	_world.enemies.release(i)
	_world.events.push(SimEventKind.ENEMY_KILLED, i, 2)
	var before: int = _written()
	var add_before: int = _ring.additive.total_written
	_world.tick += 1
	_fx.update(_world, 0.0, visual, 0)
	var n: int = _written() - before
	assert_int(n).is_equal(FxRecipes.kill_total(2, _world.enemies.alive_count, false))
	# the first particle written by a kill is the flash disc (smoke goes to its own pool)
	var first: int = posmod(_ring.additive.head - (_ring.additive.total_written - add_before), _ring.additive.capacity)
	assert_int(_ring.additive.kind_at(first)).is_equal(ParticlePack.KIND_FLASH)


func test_world_change_clears_the_pools() -> void:
	var i: int = _spawn(0)
	_world.enemies.release(i)
	_world.events.push(SimEventKind.ENEMY_KILLED, i, 0)
	_step()
	assert_int(_ring.live_count()).is_greater(0)
	var other := SimWorld.new(SimConfigLoader.load_default(2))
	_fx.update(other, 0.0, null, 0)
	assert_int(_ring.live_count()).is_equal(0)
