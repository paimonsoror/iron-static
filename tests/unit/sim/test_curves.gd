class_name TestCurves
extends GdUnitTestSuite
## Curves reference values from GDD 03 section 4.5 and 02/05 formulas.


func _g(l: int) -> float:
	return Curves.g_growth(l, 1.063, 1.032, 1.022, 200, 600)


func _ga(l: int) -> float:
	return Curves.g_growth(l, 1.058, 1.028, 1.018, 200, 600)


func test_enemy_hp_sector_1() -> void:
	assert_float(14.0 * _g(1)).is_equal_approx(14.0, 0.14)
	assert_float(14.0 * _g(10)).is_equal_approx(24.3, 0.243)
	assert_float(14.0 * _g(50)).is_equal_approx(279.0, 2.79)
	assert_float(14.0 * _g(100)).is_equal_approx(5.93e3, 59.3)


func test_enemy_atk_sector_1() -> void:
	assert_float(2.0 * _ga(1)).is_equal_approx(2.0, 0.02)
	assert_float(2.0 * _ga(10)).is_equal_approx(3.3, 0.033)
	assert_float(2.0 * _ga(50)).is_equal_approx(32.0, 0.32)
	assert_float(2.0 * _ga(100)).is_equal_approx(531.0, 5.31)


func test_sector_offsets() -> void:
	assert_float(14.0 * _g(1 + 25)).is_equal_approx(64.0, 0.64)
	assert_float(14.0 * _g(100 + 75)).is_equal_approx(5.79e5, 5.79e3)


func test_phase_boundaries_continuous() -> void:
	assert_float(_g(201) / _g(200)).is_equal_approx(1.032, 1e-9)
	assert_float(_g(200) / _g(199)).is_equal_approx(1.063, 1e-9)
	assert_float(_g(601) / _g(600)).is_equal_approx(1.022, 1e-9)
	assert_float(_g(600) / _g(599)).is_equal_approx(1.032, 1e-9)


func test_slots_for_wave() -> void:
	var waves: Array[int] = [1, 10, 50, 100, 500, 1000]
	var expected: Array[int] = [8, 15, 31, 44, 105, 157]
	for i: int in waves.size():
		assert_int(Curves.slots_for_wave(waves[i], 6.0, 2.4, 0.6, 200)).is_equal(expected[i])
	assert_int(Curves.slots_for_wave(1000000, 6.0, 2.4, 0.6, 200)).is_equal(200)


func test_scrap_per_kill_base() -> void:
	var levels: Array[int] = [1, 10, 50, 100]
	var expected: Array[int] = [2, 3, 10, 56]
	for i: int in levels.size():
		assert_int(Curves.scrap_per_kill_base(_g(levels[i]), 2.0, 0.55)).is_equal(expected[i])
	assert_int(Curves.scrap_per_kill_base(0.0001, 2.0, 0.55)).is_equal(1)


func test_data_per_kill_base() -> void:
	assert_float(Curves.data_per_kill_base(1.0, 1, 0.04, 1.0)).is_equal_approx(1.04, 1e-9)
	assert_float(Curves.data_per_kill_base(1.0, 50, 0.04, 1.0)).is_equal_approx(3.0, 1e-9)


func test_sector_reward() -> void:
	assert_float(Curves.sector_reward(1, 1.6)).is_equal(1.0)
	assert_float(Curves.sector_reward(4, 1.6)).is_equal_approx(4.096, 1e-9)
	assert_float(Curves.sector_reward(12, 1.6)).is_equal_approx(175.92, 0.01)


func test_run_factor() -> void:
	assert_float(Curves.run_factor(25, 0.10)).is_equal_approx(5.25, 1e-9)
	assert_float(Curves.run_factor(0, 0.10)).is_equal(1.0)
	assert_float(Curves.run_factor(24, 0.10)).is_equal_approx(3.4, 1e-9)


func test_foundry_mult() -> void:
	# FO-3: x1.75 every 25 levels; GDD 05 s1.2 values for f = 0.06 (hull).
	assert_float(Curves.foundry_mult(24, 0.06)).is_equal_approx(2.44, 1e-9)
	assert_float(Curves.foundry_mult(25, 0.06)).is_equal_approx(4.4, 4.4 * 0.01)
	assert_float(Curves.foundry_mult(50, 0.06)).is_equal_approx(12.3, 12.3 * 0.01)
	assert_float(Curves.foundry_mult(100, 0.06)).is_equal_approx(65.7, 65.7 * 0.01)
	assert_float(Curves.foundry_mult(200, 0.06)).is_equal_approx(1143.0, 1143.0 * 0.01)
	assert_float(Curves.foundry_mult(10, 0.06)).is_equal_approx(1.6, 1e-9)  # no early F10 bump
	assert_float(Curves.foundry_mult(0, 0.06)).is_equal(1.0)


func test_milestones_follow_the_tuning_rows() -> void:
	var t: SimTuning = SimConfigLoader.load_tuning()
	assert_int(t.run_milestone_step).is_equal(25)
	assert_float(t.run_milestone_mult).is_equal(1.5)
	assert_float(Curves.run_factor(25, 0.10, t)).is_equal_approx(Curves.run_factor(25, 0.10), 1e-12)
	t.run_milestone_step = 10
	t.run_milestone_mult = 2.0
	assert_float(Curves.run_factor(10, 0.10, t)).is_equal_approx(2.0 * 2.0, 1e-9)
	assert_float(Curves.run_factor(25, 0.10, t)).is_equal_approx(3.5 * 4.0, 1e-9)
	t.foundry_milestone_step = 5
	t.foundry_milestone_mult = 3.0
	assert_float(Curves.foundry_mult(5, 0.06, t)).is_equal_approx(1.3 * 3.0, 1e-9)
	assert_int(StatResolver.levels_to_next_milestone(7, t)).is_equal(3)


func test_upgrade_cost() -> void:
	assert_float(Curves.upgrade_cost(15.0, 1.09, 0)).is_equal(15.0)
	assert_float(Curves.upgrade_cost(15.0, 1.09, 1)).is_equal(17.0)


func test_sum_cost_sequential() -> void:
	var expected: float = (
		Curves.upgrade_cost(15.0, 1.09, 3) + Curves.upgrade_cost(15.0, 1.09, 4) + Curves.upgrade_cost(15.0, 1.09, 5)
	)
	assert_float(Curves.sum_cost(15.0, 1.09, 3, 3)).is_equal(expected)
	assert_float(Curves.sum_cost(15.0, 1.09, 3, 0)).is_equal(0.0)
