class_name TestEnemyInstanceData
extends GdUnitTestSuite


func test_frame_for_matches_floor_formula_for_1000_random_inputs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for k: int in 1000:
		var t: float = rng.randf_range(0.0, 600.0)
		var fps: float = rng.randf_range(1.0, 20.0)
		var phase: float = rng.randf_range(0.0, 8.0)
		var n: int = rng.randi_range(2, 8)
		var want: int = posmod(floori(t * fps + phase), n)
		var got: int = EnemyInstanceData.frame_for(t, fps, phase, n)
		assert_int(got).is_equal(want)
		assert_int(got).is_between(0, n - 1)


func test_frame_for_degenerate_inputs() -> void:
	assert_int(EnemyInstanceData.frame_for(5.0, 0.0, 1.0, 4)).is_equal(0)
	assert_int(EnemyInstanceData.frame_for(5.0, 8.0, 1.0, 1)).is_equal(0)
	assert_int(EnemyInstanceData.frame_for(-1.0, 8.0, 0.0, 4)).is_between(0, 3)


func test_phase_spreads_the_crowd() -> void:
	var seen: Dictionary = {}
	for i: int in 64:
		var p: float = EnemyInstanceData.phase_for(i, 4)
		assert_float(p).is_between(0.0, 4.0)
		seen[EnemyInstanceData.frame_for(2.0, 8.0, p, 4)] = true
	assert_int(seen.size()).is_equal(4)


func test_flash_decays_linearly_in_90ms_and_clamps() -> void:
	assert_float(EnemyInstanceData.decay_flash(1.0, 0.045)).is_equal_approx(0.5, 1e-5)
	assert_float(EnemyInstanceData.decay_flash(1.0, 0.09)).is_equal(0.0)
	assert_float(EnemyInstanceData.decay_flash(1.0, 1.0)).is_equal(0.0)
	assert_float(EnemyInstanceData.decay_flash(0.0, 0.01)).is_equal(0.0)
	assert_float(EnemyInstanceData.decay_flash(1.5, 0.0)).is_equal(1.0)
	var f: float = 1.0
	for k: int in 3:
		f = EnemyInstanceData.decay_flash(f, 0.03)
	assert_float(f).is_equal_approx(0.0, 1e-5)


func test_spawn_factor_and_lancer_frames() -> void:
	assert_float(EnemyInstanceData.spawn_factor(0.0)).is_equal(0.0)
	assert_float(EnemyInstanceData.spawn_factor(0.1)).is_equal_approx(0.5, 1e-6)
	assert_float(EnemyInstanceData.spawn_factor(5.0)).is_equal(1.0)
	assert_int(EnemyInstanceData.lancer_frame(-1.0)).is_equal(0)
	assert_int(EnemyInstanceData.lancer_frame(0.05)).is_equal(2)
	assert_int(EnemyInstanceData.lancer_frame(0.3)).is_equal(1)
	assert_int(EnemyInstanceData.lancer_frame(0.6)).is_equal(0)
