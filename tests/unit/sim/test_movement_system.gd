class_name TestMovementSystem
extends GdUnitTestSuite
## MovementSystem: approach, stand-off distances, prev positions, reference comparison.

const SKITTER: int = 0
const LANCER: int = 3


func _world(seed_value: int = 1) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(seed_value)
	cfg.debug_invulnerable = true
	return SimWorld.new(cfg)


func _dist(w: SimWorld, i: int) -> float:
	return sqrt(w.enemies.pos_x[i] * w.enemies.pos_x[i] + w.enemies.pos_y[i] * w.enemies.pos_y[i])


func test_skitter_arrives_in_expected_ticks() -> void:
	var w: SimWorld = _world()
	var i: int = w.debug_spawn_enemy(SKITTER, 52.0, 0.0)
	var speed: float = w.enemies.speed[i]
	var expected: int = ceili((52.0 - 2.0) / speed * 30.0)
	var ticks: int = 0
	while _dist(w, i) > 2.0 + 0.0005 and ticks < 2000:
		MovementSystem.step(w)
		ticks += 1
	assert_int(ticks).is_between(expected - 1, expected + 1)
	for k: int in 100:
		MovementSystem.step(w)
	assert_float(_dist(w, i)).is_greater_equal(w.config.tuning.melee_range - 0.001)
	assert_float(_dist(w, i)).is_less(2.001)


func test_lancer_stops_at_standoff() -> void:
	var w: SimWorld = _world()
	w.stats.optic_range = 24.0
	var i: int = w.debug_spawn_enemy(LANCER, 0.0, 52.0)
	for k: int in 2000:
		MovementSystem.step(w)
	assert_float(_dist(w, i)).is_equal_approx(20.4, 0.001)


func test_lancer_standoff_clamps() -> void:
	var w: SimWorld = _world()
	w.stats.optic_range = 10.0
	var a: int = w.debug_spawn_enemy(LANCER, 0.0, 52.0)
	for k: int in 2000:
		MovementSystem.step(w)
	assert_float(_dist(w, a)).is_equal_approx(16.0, 0.001)
	var w2: SimWorld = _world()
	w2.stats.optic_range = 80.0
	var b: int = w2.debug_spawn_enemy(LANCER, 0.0, 52.0)
	for k: int in 2000:
		MovementSystem.step(w2)
	assert_float(_dist(w2, b)).is_equal_approx(48.0, 0.001)


func test_enemy_inside_standoff_does_not_move() -> void:
	var w: SimWorld = _world()
	var i: int = w.debug_spawn_enemy(SKITTER, 1.0, 0.0)
	MovementSystem.step(w)
	assert_float(w.enemies.pos_x[i]).is_equal(1.0)
	assert_float(w.enemies.pos_y[i]).is_equal(0.0)


func test_prev_positions_hold_previous_position() -> void:
	var w: SimWorld = _world()
	var i: int = w.debug_spawn_enemy(SKITTER, 30.0, 20.0)
	for k: int in 5:
		var px: float = w.enemies.pos_x[i]
		var py: float = w.enemies.pos_y[i]
		MovementSystem.step(w)
		assert_float(w.enemies.prev_x[i]).is_equal(px)
		assert_float(w.enemies.prev_y[i]).is_equal(py)
		assert_float(_dist(w, i)).is_less(sqrt(px * px + py * py))


func test_500_enemies_match_reference() -> void:
	var w: SimWorld = _world()
	var rng: Rng = Rng.new(7, 1)
	var n: int = 500
	var rx: PackedFloat64Array = PackedFloat64Array()
	var ry: PackedFloat64Array = PackedFloat64Array()
	var rs: PackedFloat64Array = PackedFloat64Array()
	var rstop: PackedFloat64Array = PackedFloat64Array()
	var idx: PackedInt32Array = PackedInt32Array()
	for k: int in n:
		var type_index: int = LANCER if k % 5 == 0 else SKITTER
		var ang: float = rng.next_float() * TAU
		var r: float = 3.0 + rng.next_float() * 49.0
		var i: int = w.debug_spawn_enemy(type_index, cos(ang) * r, sin(ang) * r)
		assert_int(i).is_greater_equal(0)
		idx.append(i)
		rx.append(w.enemies.pos_x[i])
		ry.append(w.enemies.pos_y[i])
		rs.append(w.enemies.speed[i])
		rstop.append(20.4 if type_index == LANCER else 2.0)
	w.stats.optic_range = 24.0
	for tick_n: int in 100:
		MovementSystem.step(w)
		for k: int in n:
			var d: float = sqrt(rx[k] * rx[k] + ry[k] * ry[k])
			if d > rstop[k]:
				var nd: float = maxf(rstop[k], d - rs[k] / 30.0)
				rx[k] = rx[k] * nd / d
				ry[k] = ry[k] * nd / d
	var worst: float = 0.0
	for k: int in n:
		worst = maxf(worst, absf(w.enemies.pos_x[idx[k]] - rx[k]))
		worst = maxf(worst, absf(w.enemies.pos_y[idx[k]] - ry[k]))
	assert_float(worst).is_less(0.01)
