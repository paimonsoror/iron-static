class_name TestSimConfigMode
extends GdUnitTestSuite
## Wave mode in SimConfig and SimConfigLoader.apply_mode (M4-02).


func test_default_config_is_timed() -> void:
	var cfg: SimConfig = SimConfig.new()
	assert_str(cfg.wave_mode).is_equal("timed")
	assert_int(cfg.purge_backstop_ticks).is_equal(0)
	assert_float(cfg.reward_mult).is_equal(1.0)


func test_purge_config_from_real_data() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	var errors: PackedStringArray = SimConfigLoader.apply_mode(cfg, "purge")
	assert_int(errors.size()).is_equal(0)
	assert_str(cfg.wave_mode).is_equal("purge")
	assert_int(cfg.purge_backstop_ticks).is_equal(1800)
	assert_float(cfg.reward_mult).is_equal(1.0)


func test_timed_config_from_real_data() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	assert_int(SimConfigLoader.apply_mode(cfg, "timed").size()).is_equal(0)
	assert_str(cfg.wave_mode).is_equal("timed")
	assert_int(cfg.purge_backstop_ticks).is_equal(0)


func test_unknown_mode_falls_back_to_timed_with_an_error() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	var errors: PackedStringArray = SimConfigLoader.apply_mode(cfg, "bogus")
	assert_int(errors.size()).is_equal(1)
	assert_str(errors[0]).contains("bogus")
	assert_str(cfg.wave_mode).is_equal("timed")
	assert_int(cfg.purge_backstop_ticks).is_equal(0)


func test_config_hash_differs_by_mode_and_is_stable() -> void:
	var timed: SimConfig = SimConfigLoader.load_default(1)
	var purge_a: SimConfig = SimConfigLoader.load_default(1)
	var purge_b: SimConfig = SimConfigLoader.load_default(1)
	assert_int(SimConfigLoader.apply_mode(purge_a, "purge").size()).is_equal(0)
	assert_int(SimConfigLoader.apply_mode(purge_b, "purge").size()).is_equal(0)
	assert_str(ConfigHash.compute(timed)).is_not_equal(ConfigHash.compute(purge_a))
	assert_str(ConfigHash.compute(purge_a)).is_equal(ConfigHash.compute(purge_b))


func test_balance_setup_passes_the_mode() -> void:
	var cfg: SimConfig = BalanceSetup.make_config(3, 1, 0, {}, "vanguard", "purge")
	assert_str(cfg.wave_mode).is_equal("purge")
	assert_int(cfg.purge_backstop_ticks).is_equal(1800)
	assert_str(BalanceSetup.make_config(3, 1, 0, {}, "vanguard").wave_mode).is_equal("timed")
