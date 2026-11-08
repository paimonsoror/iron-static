class_name TestEnemyFxState
extends GdUnitTestSuite


func test_hit_sets_flash_and_it_decays_to_zero() -> void:
	var ev := SimEvents.new()
	var fx := EnemyFxState.new()
	fx.bind(ev, 16)
	ev.push(SimEventKind.ENEMY_HIT, 3, 10)
	fx.consume(ev)
	assert_float(fx.flash_at(3)).is_equal(1.0)
	assert_float(fx.flash_at(4)).is_equal(0.0)
	fx.advance(0.045, 16)
	assert_float(fx.flash_at(3)).is_equal_approx(0.5, 1e-5)
	fx.advance(0.05, 16)
	assert_float(fx.flash_at(3)).is_equal(0.0)


func test_spawn_resets_flash_and_starts_spawn_in() -> void:
	var ev := SimEvents.new()
	var fx := EnemyFxState.new()
	fx.bind(ev, 16)
	assert_float(fx.spawn_at(5)).is_equal(1.0)  # alive at bind: no spawn-in
	ev.push(SimEventKind.ENEMY_HIT, 5, 1)
	ev.push(SimEventKind.ENEMY_SPAWNED, 5, 0)  # slot reused
	fx.consume(ev)
	assert_float(fx.flash_at(5)).is_equal(0.0)
	assert_float(fx.spawn_at(5)).is_equal(0.0)
	fx.advance(0.1, 16)
	assert_float(fx.spawn_at(5)).is_equal_approx(0.5, 1e-5)
	fx.advance(0.2, 16)
	assert_float(fx.spawn_at(5)).is_equal(1.0)


func test_out_of_range_events_and_old_events_are_ignored() -> void:
	var ev := SimEvents.new()
	ev.push(SimEventKind.ENEMY_HIT, 2, 1)
	var fx := EnemyFxState.new()
	fx.bind(ev, 8)  # skips what was pushed before the bind
	ev.push(SimEventKind.ENEMY_HIT, 99, 1)
	ev.push(SimEventKind.ENEMY_HIT, -1, 1)
	fx.consume(ev)
	assert_float(fx.flash_at(2)).is_equal(0.0)
	assert_float(fx.flash_at(99)).is_equal(0.0)


func test_rebind_with_same_capacity_does_not_resize() -> void:
	var ev := SimEvents.new()
	var fx := EnemyFxState.new()
	fx.bind(ev, 32)
	var n: int = fx.resize_count
	fx.bind(ev, 32)
	assert_int(fx.resize_count).is_equal(n)
