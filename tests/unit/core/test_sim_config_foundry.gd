class_name TestSimConfigFoundry
extends GdUnitTestSuite
## SimConfigLoader.apply_foundry / apply_frame (M3-06, M3-21).


func _index(cfg: SimConfig, id: String) -> int:
	for i: int in cfg.upgrades.size():
		if cfg.upgrades[i].id == id:
			return i
	return -1


func test_arrays_are_aligned_with_upgrades() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	SimConfigLoader.apply_foundry(cfg, {"laser_output": 25, "cycle_rate": 7})
	assert_int(cfg.foundry_levels.size()).is_equal(cfg.upgrades.size())
	assert_int(cfg.foundry_f.size()).is_equal(cfg.upgrades.size())
	assert_int(cfg.foundry_levels[_index(cfg, "laser_output")]).is_equal(25)
	assert_int(cfg.foundry_levels[_index(cfg, "cycle_rate")]).is_equal(7)
	assert_float(cfg.foundry_f[_index(cfg, "laser_output")]).is_equal(0.06)
	assert_int(cfg.foundry_levels[_index(cfg, "crit_chance")]).is_equal(0)
	assert_int(cfg.foundry_levels[_index(cfg, "reinvest")]).is_equal(0)


func test_levels_are_clamped_to_the_cap_and_zero() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	SimConfigLoader.apply_foundry(cfg, {"cycle_rate": 999, "hull_integrity": -4, "unknown_row": 3})
	assert_int(cfg.foundry_levels[_index(cfg, "cycle_rate")]).is_equal(50)
	assert_int(cfg.foundry_levels[_index(cfg, "hull_integrity")]).is_equal(0)


func test_foundry_changes_the_stat_block() -> void:
	var plain: SimConfig = SimConfigLoader.load_default(1)
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	SimConfigLoader.apply_foundry(cfg, {"laser_output": 25})
	var a: StatBlock = StatBlock.from_resolver(plain.upgrades, PackedInt32Array())
	var b: StatBlock = StatBlock.from_resolver(cfg.upgrades, PackedInt32Array(), cfg.foundry_levels, cfg.foundry_f)
	assert_float(a.laser_output).is_equal(10.0)
	assert_float(b.laser_output).is_equal_approx(10.0 * 3.9, 10.0 * 3.9 * 0.02)
	assert_float(b.hull_integrity).is_equal(a.hull_integrity)


func test_all_zero_foundry_keeps_the_config_hash() -> void:
	var plain: SimConfig = SimConfigLoader.load_default(1)
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	SimConfigLoader.apply_foundry(cfg, {})
	assert_str(ConfigHash.compute(cfg)).is_equal(ConfigHash.compute(plain))
	SimConfigLoader.apply_foundry(cfg, {"laser_output": 1})
	assert_str(ConfigHash.compute(cfg)).is_not_equal(ConfigHash.compute(plain))


func test_apply_frame_builds_mods() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	assert_bool(SimConfigLoader.apply_frame(cfg, "bulwark")).is_true()
	assert_str(cfg.frame_id).is_equal("bulwark")
	assert_float(cfg.frame.hull_mult).is_equal(3.0)
	assert_int(cfg.frame.passive).is_equal(FrameMods.PASSIVE_BASTION)
	assert_bool(cfg.frame.is_runnable()).is_true()
	assert_bool(SimConfigLoader.apply_frame(cfg, "striker")).is_true()
	assert_int(cfg.frame.passive).is_equal(FrameMods.PASSIVE_OVERCLOCK)


func test_vanguard_is_neutral_and_m6_frames_are_not_runnable() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	assert_bool(SimConfigLoader.apply_frame(cfg, "vanguard")).is_true()
	assert_bool(cfg.frame.is_neutral()).is_true()
	assert_bool(SimConfigLoader.apply_frame(cfg, "longshot")).is_true()
	assert_bool(cfg.frame.is_runnable()).is_false()
