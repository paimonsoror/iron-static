class_name TestProjectileSystem
extends GdUnitTestSuite
## ProjectileSystem: bolt travel, hit through plating, expiry (M1-12).

const LANCER: int = 3


func _world() -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.debug_invulnerable = true
	return SimWorld.new(cfg)


func test_bolt_from_standoff_reaches_cinder_in_expected_ticks() -> void:
	var w: SimWorld = _world()
	var d: float = EnemyAttackSystem.lancer_standoff(w)
	assert_int(w.debug_spawn_bolt(d, 0.0, -18.0, 0.0, 6.0)).is_greater_equal(0)
	var expected: int = ceili((d - 2.0) / 18.0 * 30.0)
	var hit_at: int = -1
	for k: int in 80:
		ProjectileSystem.step(w)
		if w.projectiles.alive_count == 0:
			hit_at = k + 1
			break
	assert_int(hit_at).is_between(expected - 1, expected + 1)
	assert_float(w.cinder.max_hp - w.cinder.hp).is_equal_approx(6.0, 0.0001)


func test_bolt_damage_goes_through_plating() -> void:
	var w: SimWorld = _world()
	w.stats.plating_pct = 0.5
	assert_int(w.debug_spawn_bolt(1.0, 0.0, -18.0, 0.0, 6.0)).is_greater_equal(0)
	ProjectileSystem.step(w)
	assert_float(w.cinder.max_hp - w.cinder.hp).is_equal_approx(3.0, 0.0001)
	assert_int(w.projectiles.alive_count).is_equal(0)


func test_hit_pushes_cinder_hit_event_with_attacker_type() -> void:
	var w: SimWorld = _world()
	var b: int = w.debug_spawn_bolt(1.0, 0.0, -18.0, 0.0, 6.0)
	w.projectiles.owner_type[b] = LANCER
	var before: int = w.events.total_pushed
	ProjectileSystem.step(w)
	assert_int(w.events.total_pushed).is_equal(before + 1)
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(out.resize(SimEvents.CAPACITY * SimEvents.FIELDS)).is_equal(OK)
	var n: int = w.events.drain(0, out)
	assert_int(out[(n - 1) * 4 + 1]).is_equal(SimEventKind.CINDER_HIT)
	assert_int(out[(n - 1) * 4 + 2]).is_equal(6)
	assert_int(out[(n - 1) * 4 + 3]).is_equal(LANCER)


func test_lethal_bolt_sets_death_cause() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	var w: SimWorld = SimWorld.new(cfg)
	w.cinder.setup(5.0, false)
	var b: int = w.debug_spawn_bolt(1.0, 0.0, -18.0, 0.0, 6.0)
	w.projectiles.owner_type[b] = LANCER
	ProjectileSystem.step(w)
	assert_bool(w.cinder.alive).is_false()
	assert_int(w.run.death_cause).is_equal(LANCER)


func test_expired_bolt_is_released_silently() -> void:
	var w: SimWorld = _world()
	var b: int = w.debug_spawn_bolt(40.0, 0.0, 0.0, 0.0, 6.0)
	w.projectiles.ttl_ticks[b] = 3
	var before: int = w.events.total_pushed
	for k: int in 3:
		ProjectileSystem.step(w)
	assert_int(w.projectiles.alive_count).is_equal(0)
	assert_int(w.events.total_pushed).is_equal(before)
	assert_float(w.cinder.hp).is_equal(w.cinder.max_hp)


func test_no_enemies_projectile_store_stays_empty() -> void:
	var w: SimWorld = _world()
	for k: int in 100:
		EnemyAttackSystem.step(w)
		ProjectileSystem.step(w)
		w.tick += 1
	assert_int(w.projectiles.alive_count).is_equal(0)
	assert_int(w.projectiles.high_water).is_equal(0)


func test_lancer_end_to_end_bolt_hits_through_systems() -> void:
	var w: SimWorld = _world()
	var d: float = EnemyAttackSystem.lancer_standoff(w)
	var i: int = w.debug_spawn_enemy(LANCER, d, 0.0)
	var dmg: float = w.enemies.dmg[i]
	for k: int in 40:
		EnemyAttackSystem.step(w)
		ProjectileSystem.step(w)
		w.tick += 1
	assert_float(w.cinder.max_hp - w.cinder.hp).is_equal_approx(dmg, 0.0001)
	assert_int(w.projectiles.alive_count).is_equal(0)


func test_many_bolts_never_exceed_capacity() -> void:
	var w: SimWorld = _world()
	var d: float = EnemyAttackSystem.lancer_standoff(w)
	for k: int in 100:
		assert_int(w.debug_spawn_enemy(LANCER, d, 0.0)).is_greater_equal(0)
	var cap: int = w.projectiles.capacity
	for k: int in 200:
		EnemyAttackSystem.step(w)
		ProjectileSystem.step(w)
		w.tick += 1
		assert_int(w.projectiles.alive_count).is_less_equal(cap)
