class_name TestPowerRating
extends GdUnitTestSuite
## Power Rating helpers (M2-13).


func test_level_0_stats_give_about_pr_32() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	var s: StatBlock = StatBlock.from_base(cfg)
	assert_float(PowerRating.ref_ehp(s)).is_equal_approx(160.0, 1.0e-9)
	assert_float(PowerRating.ref_dmg(s)).is_equal_approx(10.1, 0.2)
	assert_float(PowerRating.power_rating(s)).is_between(30.0, 34.0)


func test_formula_terms() -> void:
	var s: StatBlock = StatBlock.new()
	s.laser_output = 100.0
	s.cycle_rate = 2.0
	s.crit_chance = 0.5
	s.crit_mult = 3.0
	s.hull_integrity = 200.0
	s.nano_repair = 10.0
	s.plating_flat = 40.0
	s.plating_pct = 0.5
	assert_float(PowerRating.ref_dmg(s)).is_equal_approx(400.0, 1.0e-9)
	assert_float(PowerRating.ref_ehp(s)).is_equal_approx(1680.0, 1.0e-9)
	assert_float(PowerRating.power_rating(s)).is_equal_approx(10.0 * log(672000.0) / log(10.0), 1.0e-9)


func test_zero_stats_give_zero() -> void:
	assert_float(PowerRating.power_rating(StatBlock.new())).is_equal(0.0)
