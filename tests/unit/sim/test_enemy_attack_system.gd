class_name TestEnemyAttackSystem
extends GdUnitTestSuite
## EnemyAttackSystem: melee bite escalation, intake, death cause, lancer firing (M1-11, M1-12).

const SKITTER: int = 0
const LANCER: int = 3
const CONTACT: float = 2.0


func _world(invulnerable: bool = true) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.debug_invulnerable = invulnerable
	return SimWorld.new(cfg)


## Runs the attack system for `ticks` ticks (advancing world.tick only) and returns CINDER_HIT damages by tick.
func _run(w: SimWorld, ticks: int) -> Dictionary:
	var hits: Dictionary = {}
	for k: int in ticks:
		var before: int = w.events.total_pushed
		EnemyAttackSystem.step(w)
		if w.events.total_pushed > before:
			hits[w.tick] = w.cinder.max_hp - w.cinder.hp
		w.tick += 1
	return hits


func _cinder_hits(w: SimWorld) -> Array[int]:
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(out.resize(SimEvents.CAPACITY * SimEvents.FIELDS)).is_equal(OK)
	var n: int = w.events.drain(0, out)
	var ticks: Array[int] = []
	for k: int in n:
		if out[k * 4 + 1] == SimEventKind.CINDER_HIT:
			ticks.append(out[k * 4])
	return ticks


func test_skitter_bite_escalation_ticks_and_damage() -> void:
	var w: SimWorld = _world()
	w.cinder.setup(1000.0, true)
	var i: int = w.debug_spawn_enemy(SKITTER, CONTACT, 0.0)
	var dmg: float = w.enemies.dmg[i]
	assert_float(dmg).is_equal_approx(2.0, 0.0001)
	var hp_before: float = w.cinder.hp
	var taken: Array[float] = []
	var hit_ticks: Array[int] = []
	for k: int in 61:
		var hp0: float = w.cinder.hp
		EnemyAttackSystem.step(w)
		if w.cinder.hp < hp0:
			taken.append(hp0 - w.cinder.hp)
			hit_ticks.append(w.tick)
		w.tick += 1
	assert_array(hit_ticks).is_equal([0, 30, 60])
	assert_float(taken[0]).is_equal_approx(2.0, 0.0001)
	assert_float(taken[1]).is_equal_approx(2.06, 0.0001)
	assert_float(taken[2]).is_equal_approx(2.1218, 0.0001)
	assert_float(hp_before - w.cinder.hp).is_equal_approx(6.1818, 0.0001)


func test_bite_multiplier_caps_at_two() -> void:
	var w: SimWorld = _world()
	w.cinder.setup(100000.0, true)
	var i: int = w.debug_spawn_enemy(SKITTER, CONTACT, 0.0)
	var dmg: float = w.enemies.dmg[i]
	w.enemies.melee_hits[i] = 24
	var hp0: float = w.cinder.hp
	EnemyAttackSystem.step(w)
	assert_float(hp0 - w.cinder.hp).is_equal_approx(dmg * 2.0, 0.0001)
	w.tick += 30
	w.enemies.melee_hits[i] = 500
	hp0 = w.cinder.hp
	EnemyAttackSystem.step(w)
	assert_float(hp0 - w.cinder.hp).is_equal_approx(dmg * 2.0, 0.0001)


func test_dies_on_third_hit_with_death_cause() -> void:
	var w: SimWorld = _world(false)
	w.cinder.setup(5.0, false)
	assert_int(w.debug_spawn_enemy(SKITTER, CONTACT, 0.0)).is_greater_equal(0)
	for k: int in 61:
		EnemyAttackSystem.step(w)
		w.tick += 1
	assert_bool(w.cinder.alive).is_false()
	assert_int(w.run.death_cause).is_equal(SKITTER)
	assert_int(_cinder_hits(w).size()).is_equal(3)


func test_death_cause_untouched_when_hit_not_lethal() -> void:
	var w: SimWorld = _world(false)
	w.cinder.setup(100.0, false)
	assert_int(w.debug_spawn_enemy(SKITTER, CONTACT, 0.0)).is_greater_equal(0)
	EnemyAttackSystem.step(w)
	assert_bool(w.cinder.alive).is_true()
	assert_int(w.run.death_cause).is_equal(-1)


func test_outside_melee_range_never_attacks() -> void:
	var w: SimWorld = _world()
	assert_int(w.debug_spawn_enemy(SKITTER, 2.02, 0.0)).is_greater_equal(0)
	assert_dict(_run(w, 120)).is_not_null()
	assert_float(w.cinder.hp).is_equal(w.cinder.max_hp)
	assert_int(w.events.total_pushed).is_equal(2)  # wave start + spawn only


func test_slack_allows_attack_just_outside_stop_distance() -> void:
	var w: SimWorld = _world()
	assert_int(w.debug_spawn_enemy(SKITTER, 2.009, 0.0)).is_greater_equal(0)
	EnemyAttackSystem.step(w)
	assert_float(w.cinder.hp).is_less(w.cinder.max_hp)


func test_two_enemies_attack_independently() -> void:
	var w: SimWorld = _world()
	w.cinder.setup(1000.0, true)
	var a: int = w.debug_spawn_enemy(SKITTER, CONTACT, 0.0)
	w.tick = 10
	var b: int = w.debug_spawn_enemy(SKITTER, 0.0, CONTACT)
	for k: int in 41:
		EnemyAttackSystem.step(w)
		w.tick += 1
	# a attacked at 10 (first seen), 40; b at 10, 40 -> its own counters.
	assert_int(w.enemies.melee_hits[a]).is_equal(2)
	assert_int(w.enemies.melee_hits[b]).is_equal(2)
	w.enemies.next_attack_tick[b] = 9999
	w.tick = w.enemies.next_attack_tick[a]
	EnemyAttackSystem.step(w)
	assert_int(w.enemies.melee_hits[a]).is_equal(3)
	assert_int(w.enemies.melee_hits[b]).is_equal(2)


func test_plating_percent_halves_damage() -> void:
	var w: SimWorld = _world()
	w.cinder.setup(1000.0, true)
	w.stats.plating_pct = 0.5
	assert_int(w.debug_spawn_enemy(SKITTER, CONTACT, 0.0)).is_greater_equal(0)
	EnemyAttackSystem.step(w)
	assert_float(w.cinder.max_hp - w.cinder.hp).is_equal_approx(1.0, 0.0001)


func test_plating_flat_floor_applies() -> void:
	var w: SimWorld = _world()
	w.cinder.setup(1000.0, true)
	w.stats.plating_flat = 50.0
	assert_int(w.debug_spawn_enemy(SKITTER, CONTACT, 0.0)).is_greater_equal(0)
	EnemyAttackSystem.step(w)
	var floor_pct: float = w.config.tuning.min_damage_floor
	assert_float(w.cinder.max_hp - w.cinder.hp).is_equal_approx(2.0 * floor_pct, 0.0001)


func test_lancer_standoff_formula() -> void:
	var w: SimWorld = _world()
	assert_float(w.stats.optic_range).is_equal_approx(24.0, 0.0001)
	assert_float(EnemyAttackSystem.lancer_standoff(w)).is_equal_approx(20.4, 0.0001)


func test_lancer_fires_on_arrival_and_every_60_ticks() -> void:
	var w: SimWorld = _world()
	var d: float = EnemyAttackSystem.lancer_standoff(w)
	var i: int = w.debug_spawn_enemy(LANCER, d, 0.0)
	var fire_ticks: Array[int] = []
	var seen: int = 0
	for k: int in 181:
		EnemyAttackSystem.step(w)
		var total: int = w.projectiles.alive_count
		if total != seen:
			fire_ticks.append(w.tick)
			seen = total
		w.tick += 1
	assert_array(fire_ticks).is_equal([0, 60, 120, 180])
	var j: int = 0
	assert_float(w.projectiles.damage[j]).is_equal_approx(w.enemies.dmg[i], 0.0001)
	assert_float(w.projectiles.vel_x[j]).is_equal_approx(-18.0, 0.001)
	assert_float(w.projectiles.vel_y[j]).is_equal_approx(0.0, 0.001)
	assert_int(w.projectiles.owner_type[j]).is_equal(LANCER)
	assert_int(w.projectiles.ttl_ticks[j]).is_equal(w.bolt_ttl_ticks())


func test_lancer_does_not_fire_before_in_range() -> void:
	var w: SimWorld = _world()
	assert_int(w.debug_spawn_enemy(LANCER, 30.0, 0.0)).is_greater_equal(0)
	assert_dict(_run(w, 120)).is_not_null()
	assert_int(w.projectiles.alive_count).is_equal(0)


func test_full_projectile_store_does_not_crash() -> void:
	var w: SimWorld = _world()
	var d: float = EnemyAttackSystem.lancer_standoff(w)
	assert_int(w.debug_spawn_enemy(LANCER, d, 0.0)).is_greater_equal(0)
	for k: int in w.projectiles.capacity:
		assert_int(w.debug_spawn_bolt(40.0, 0.0, 0.0, 0.0, 1.0)).is_greater_equal(0)
	assert_int(w.debug_spawn_bolt(40.0, 0.0, 0.0, 0.0, 1.0)).is_equal(-1)
	EnemyAttackSystem.step(w)
	assert_int(w.projectiles.alive_count).is_equal(w.projectiles.capacity)
