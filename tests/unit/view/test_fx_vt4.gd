class_name TestFxVt4
extends GdUnitTestSuite
## VT-4 (docs/design/12 sections 4, 7, 8): deflection sparks and repair motes. Tier looks come from the plating_pct
## and nano_repair run levels; MK I / PLATED I / no tier is bit-identical to before (nothing extra is written).

var _world: SimWorld
var _ring: ParticleRenderer
var _fx: FxSpawner
var _enemies: EnemyRenderer


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
	_fx.update(_world, 0.0, null, 0)


func _level(upgrade_id: String, level: int) -> void:
	for i: int in _world.config.upgrades.size():
		if _world.config.upgrades[i].id == upgrade_id:
			_world.run_levels[i] = level


func _written() -> int:
	return _ring.additive.total_written + _ring.smoke.total_written


func _vis(tier: VisualQuality.Tier, reduce: bool = false, contrast: bool = false) -> VisualSettings:
	var v := VisualSettings.new()
	v.quality = VisualQuality.for_tier(tier)
	v.reduce_motion = reduce
	v.high_contrast = contrast
	return v


## Runs `seconds` of sim time in 1/30 s frames and returns the particles written.
func _run(seconds: float, vis: VisualSettings = null) -> int:
	var before: int = _written()
	for i: int in roundi(seconds * 30.0):
		_world.tick += 1
		_fx.update(_world, 0.0, vis, 0)
	return _written() - before


func _hit(vis: VisualSettings = null) -> int:
	var before: int = _written()
	_world.events.push(SimEventKind.CINDER_HIT, 10, 0)
	_world.tick += 1
	_fx.update(_world, 0.0, vis, 0)
	return _written() - before


func test_no_tier_hit_and_no_motes_write_only_the_old_recipe() -> void:
	_level("plating_pct", 2)  # below PLATED II: no deflection
	assert_int(_hit()).is_equal(FxRecipes.CINDER_HIT_SPARKS)
	assert_int(_run(3.0)).is_equal(0)
	assert_int(_fx.motes_spawned).is_equal(0)
	assert_int(_fx.deflects_spawned).is_equal(0)


func test_deflect_from_plated_ii_scales_with_tier() -> void:
	var counts := PackedInt32Array()
	for lvl: int in [3, 8, 16, 30]:
		_level("plating_pct", lvl)
		counts.append(_hit() - FxRecipes.CINDER_HIT_SPARKS)
	assert_int(counts[0]).is_equal(0)  # PLATED I: bit-identical to today
	assert_int(counts[1]).is_equal(4 + 5)  # flash, ring, halo, flare + 5 sparks
	assert_int(counts[2]).is_equal(4 + 6)
	assert_int(counts[3]).is_equal(4 + 6)
	assert_int(_fx.deflects_spawned).is_equal(3)


func test_deflect_point_is_on_the_plate_edge_at_the_hit_bearing() -> void:
	_level("plating_pct", 8)
	var first: int = _ring.additive.head + FxRecipes.CINDER_HIT_SPARKS
	@warning_ignore("return_value_discarded")
	_hit()
	var p: Vector2 = _ring.additive.pos_at(first)
	assert_float(p.length()).is_equal_approx(_fx.emitter.cinder_radius_px * FxRecipes.DEFLECT_EDGE, 0.5)
	assert_float(absf(angle_difference(p.angle(), _fx.emitter.last_hit_angle))).is_less(0.01)


func test_deflect_quality_and_reduce_motion() -> void:
	assert_int(FxRecipes.deflect_sparks(0, false, 1.4)).is_equal(6)
	assert_int(FxRecipes.deflect_sparks(1, false, 1.4)).is_equal(4)
	assert_int(FxRecipes.deflect_sparks(2, false, 1.4)).is_equal(0)
	assert_int(FxRecipes.deflect_sparks(0, true, 1.4)).is_equal(3)
	_level("plating_pct", 30)
	assert_int(_hit(_vis(VisualQuality.Tier.LOW))).is_equal(FxRecipes.CINDER_HIT_SPARKS)  # LOW: old sparks only
	# reduce motion: flash, halo, flare + 3 sparks
	assert_int(_hit(_vis(VisualQuality.Tier.HIGH, true))).is_equal(FxRecipes.CINDER_HIT_SPARKS + 3 + 3)
	# MID: flash, halo, flare + 4 sparks, no ring
	assert_int(_hit(_vis(VisualQuality.Tier.MID))).is_equal(FxRecipes.CINDER_HIT_SPARKS + 3 + 4)


func test_deflect_respects_the_cinder_hit_budget() -> void:
	_level("plating_pct", 16)
	for i: int in 10:
		_world.events.push(SimEventKind.CINDER_HIT, 10, 0)
	_world.tick += 1
	_fx.update(_world, 0.0, null, 0)
	assert_int(_fx.deflects_spawned).is_equal(FxRecipes.CINDER_HIT_BUDGET)


func test_mote_counts_per_tier() -> void:
	for pair: Array in [[0, 0], [5, 5], [12, 10], [25, 16]]:
		_fx = FxSpawner.new()
		_fx.setup(_ring, _enemies)
		_fx.update(_world, 0.0, null, 0)
		var lvl: int = pair[0]
		_level("nano_repair", lvl)
		_world.cinder.hp = _world.cinder.max_hp * 0.5  # hurt: 100% rate
		var n: int = _run(1.3)
		var expect_n: int = pair[1]
		assert_int(_fx.motes_spawned).is_between(maxi(expect_n - 1, 0), expect_n + 1)
		assert_int(n).is_equal(_fx.motes_spawned * 2)  # mote + halo
	assert_float(FxRecipes.mote_rate(16, false)).is_equal_approx(16.0 / 1.3 * 0.4, 0.001)
	assert_float(FxRecipes.mote_rate(16, true)).is_equal_approx(16.0 / 1.3, 0.001)


func test_motes_idle_rate_is_forty_percent_at_full_integrity() -> void:
	_level("nano_repair", 25)
	_world.cinder.hp = _world.cinder.max_hp
	@warning_ignore("return_value_discarded")
	_run(6.5)
	var idle: int = _fx.motes_spawned
	assert_int(idle).is_between(30, 34)  # 16 / 1.3 * 0.4 * 6.5 = 32
	_world.cinder.hp = _world.cinder.max_hp - 1.0
	@warning_ignore("return_value_discarded")
	_run(6.5)
	assert_int(_fx.motes_spawned - idle).is_between(78, 82)  # 16 / 1.3 * 6.5 = 80


func test_motes_quality_reduce_motion_and_high_contrast() -> void:
	assert_int(FxRecipes.mote_count(16, 0, false)).is_equal(16)
	assert_int(FxRecipes.mote_count(16, 1, false)).is_equal(10)
	assert_int(FxRecipes.mote_count(16, 2, false)).is_equal(0)
	assert_int(FxRecipes.mote_count(16, 0, true)).is_equal(8)
	assert_int(FxRecipes.mote_count(5, 1, true)).is_equal(3)
	_level("nano_repair", 25)
	_world.cinder.hp = 1.0
	assert_int(_run(2.0, _vis(VisualQuality.Tier.LOW))).is_equal(0)
	assert_int(_run(2.0, _vis(VisualQuality.Tier.HIGH, false, true))).is_equal(0)
	# MID: no halo, so one particle per mote
	var before_motes: int = _fx.motes_spawned
	var n: int = _run(2.0, _vis(VisualQuality.Tier.MID))
	assert_int(n).is_equal(_fx.motes_spawned - before_motes)
	assert_int(n).is_greater(0)


func test_reduce_motion_motes_fade_in_place() -> void:
	_level("nano_repair", 25)
	_world.cinder.hp = 1.0
	var slot: int = _ring.additive.head
	@warning_ignore("return_value_discarded")
	_run(0.5, _vis(VisualQuality.Tier.HIGH, true))
	var d: int = slot * ParticlePack.DATA_FLOATS
	assert_float(_ring.additive.data[d + 4]).is_equal(0.0)
	assert_float(_ring.additive.data[d + 5]).is_equal(0.0)


func test_motes_orbit_with_tangential_velocity() -> void:
	_level("nano_repair", 25)
	_world.cinder.hp = 1.0
	var slot: int = _ring.additive.head
	@warning_ignore("return_value_discarded")
	_run(0.5)
	var p: Vector2 = _ring.additive.pos_at(slot)
	var d: int = slot * ParticlePack.DATA_FLOATS
	var v := Vector2(_ring.additive.data[d + 4], _ring.additive.data[d + 5])
	assert_float(absf(v.normalized().dot(p.normalized()))).is_less(0.4)  # mostly tangential
	assert_float(v.length()).is_between(60.0, 125.0)
	assert_float(p.length()).is_greater(_fx.emitter.cinder_radius_px)


func test_motes_stay_within_the_live_and_frame_budgets() -> void:
	_level("nano_repair", 25)
	_world.cinder.hp = 1.0
	@warning_ignore("return_value_discarded")
	_run(5.0)
	assert_int(_ring.additive.live_count(_fx.emitter.now)).is_less_equal(34)
	# a frame whose hit/kill budget is spent spawns no motes
	var before: int = _fx.motes_spawned
	_fx._particle_budget = 0
	_fx._motes(_world, 1.0, 0, false, false)
	assert_int(_fx.motes_spawned).is_equal(before)


func test_tier_refresh_follows_the_level() -> void:
	_level("plating_pct", 8)
	_fx.update(_world, 0.0, null, 0)
	assert_float(_fx._deflect_scale).is_equal(1.0)
	_level("plating_pct", 30)
	_fx.update(_world, 0.0, null, 0)
	assert_float(_fx._deflect_scale).is_equal_approx(1.4, 0.001)
	_level("plating_pct", 0)
	_fx.update(_world, 0.0, null, 0)
	assert_float(_fx._deflect_scale).is_equal(0.0)
