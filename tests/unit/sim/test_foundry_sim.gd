class_name TestFoundrySim
extends GdUnitTestSuite
## Foundry levels entering the sim as config data (M3-07).

# Re-pinned in M4-02 (the mode section is always hashed).
## The neutral-config hash is the replay golden (R1: it changes with every new tuning row; pinned once).
const PRE_M3_CONFIG_HASH: String = TestReplay.GOLDEN_CONFIG_HASH
const F_D_LASER: float = 0.06
const F_D_HULL: float = 0.06


func _cfg(seed_value: int = 3) -> SimConfig:
	return SimConfigLoader.load_default(seed_value)


func _row(cfg: SimConfig, id: String) -> int:
	for i: int in cfg.upgrades.size():
		if cfg.upgrades[i].id == id:
			return i
	return -1


## Sets Foundry level (and the Type D factor) of one row, arrays aligned with `cfg.upgrades`.
func _set_foundry(cfg: SimConfig, id: String, level: int, f: float = 0.0) -> void:
	if cfg.foundry_levels.size() != cfg.upgrades.size():
		var lv: PackedInt32Array = PackedInt32Array()
		var ff: PackedFloat64Array = PackedFloat64Array()
		if lv.resize(cfg.upgrades.size()) != OK or ff.resize(cfg.upgrades.size()) != OK:
			push_error("resize failed")
		lv.fill(0)
		ff.fill(0.0)
		cfg.foundry_levels = lv
		cfg.foundry_f = ff
	var i: int = _row(cfg, id)
	cfg.foundry_levels[i] = level
	cfg.foundry_f[i] = f


func test_laser_output_f25_starts_at_4_4x() -> void:
	var cfg: SimConfig = _cfg()
	_set_foundry(cfg, "laser_output", 25, F_D_LASER)
	var w: SimWorld = SimWorld.new(cfg)
	assert_float(w.stats.laser_output).is_equal_approx(43.75, 0.01 * 43.75)
	assert_float(w.stats.laser_output).is_equal_approx(10.0 * Curves.foundry_mult(25, F_D_LASER), 1.0e-9)


func test_all_zero_foundry_is_bit_identical_to_no_foundry() -> void:
	var plain: SimWorld = SimWorld.new(_cfg())
	var cfg: SimConfig = _cfg()
	_set_foundry(cfg, "laser_output", 0, F_D_LASER)  # arrays present, levels zero
	var zero: SimWorld = SimWorld.new(cfg)
	assert_str(zero.state_hash()).is_equal(plain.state_hash())
	assert_str(ConfigHash.compute(cfg)).is_equal(ConfigHash.compute(_cfg()))
	assert_str(ConfigHash.compute(_cfg())).is_equal(PRE_M3_CONFIG_HASH)
	for k: int in 900:
		plain.step()
		zero.step()
	assert_str(zero.state_hash()).is_equal(plain.state_hash())


func test_hull_f25_raises_start_hp_by_formula() -> void:
	var cfg: SimConfig = _cfg()
	_set_foundry(cfg, "hull_integrity", 25, F_D_HULL)
	var w: SimWorld = SimWorld.new(cfg)
	var expected: float = 100.0 * (1.0 + F_D_HULL * 25.0) * 1.75
	assert_float(w.cinder.hp).is_equal_approx(expected, 1.0e-9)
	assert_float(w.cinder.max_hp).is_equal_approx(expected, 1.0e-9)
	assert_float(w.cinder.hp / 100.0).is_equal_approx(2.5 * 1.75, 1.0e-9)


func test_cycle_rate_type_c_adds_step_and_clamps_at_cap() -> void:
	var cfg: SimConfig = _cfg()
	_set_foundry(cfg, "cycle_rate", 50)
	var w: SimWorld = SimWorld.new(cfg)
	assert_float(w.stats.cycle_rate).is_equal_approx(1.0 + 0.04 * 50.0, 1.0e-9)
	var over: SimConfig = _cfg()
	_set_foundry(over, "cycle_rate", 200)
	var w2: SimWorld = SimWorld.new(over)
	assert_float(w2.stats.cycle_rate).is_equal_approx(1.0 + 0.04 * 50.0, 1.0e-9)


func test_config_hash_differs_for_nonzero_foundry() -> void:
	var cfg: SimConfig = _cfg()
	_set_foundry(cfg, "laser_output", 3, F_D_LASER)
	var h: String = ConfigHash.compute(cfg)
	assert_str(h).is_not_equal(PRE_M3_CONFIG_HASH)
	var other: SimConfig = _cfg()
	_set_foundry(other, "laser_output", 4, F_D_LASER)
	assert_str(ConfigHash.compute(other)).is_not_equal(h)
	var other_f: SimConfig = _cfg()
	_set_foundry(other_f, "laser_output", 3, F_D_LASER + 0.01)
	assert_str(ConfigHash.compute(other_f)).is_not_equal(h)


func test_preview_values_include_foundry_and_match_the_world_after_buy() -> void:
	var cfg: SimConfig = _cfg()
	_set_foundry(cfg, "laser_output", 25, F_D_LASER)
	_set_foundry(cfg, "cycle_rate", 10)
	var w: SimWorld = SimWorld.new(cfg)
	for id: String in ["laser_output", "cycle_rate"]:
		var i: int = _row(cfg, id)
		var p: UpgradePreview = UpgradeSystem.preview(w, i, 1)
		assert_float(p.current_value).is_equal_approx(_stat(w.stats, id), 1.0e-9)
		w.economy.scrap = BigNum.from_float(1.0e6)
		var p2: UpgradePreview = UpgradeSystem.preview(w, i, 1)
		assert_int(w.command_buy(i, 1)).is_equal(1)
		assert_float(_stat(w.stats, id)).is_equal_approx(p2.next_value, 1.0e-9)
	var laser: UpgradePreview = UpgradeSystem.preview(w, _row(cfg, "laser_output"), 1)
	assert_float(laser.current_value).is_greater(39.0)


func test_buying_hull_with_foundry_keeps_delta_consistent() -> void:
	var cfg: SimConfig = _cfg()
	_set_foundry(cfg, "hull_integrity", 10, F_D_HULL)
	var w: SimWorld = SimWorld.new(cfg)
	w.economy.scrap = BigNum.from_float(1.0e6)
	var i: int = _row(cfg, "hull_integrity")
	assert_int(w.command_buy(i, 1)).is_equal(1)
	assert_float(w.cinder.max_hp).is_equal_approx(w.stats.hull_integrity, 1.0e-9)
	assert_float(w.stats.hull_integrity).is_equal_approx(100.0 * 1.1 * Curves.foundry_mult(10, F_D_HULL), 1.0e-9)


func test_greedy4_with_foundry_is_not_weaker_than_fresh() -> void:
	# Informational check (gated in M3-08): median death wave over 10 seeds.
	var fresh: PackedInt32Array = PackedInt32Array()
	var strong: PackedInt32Array = PackedInt32Array()
	for s: int in range(1, 11):
		if fresh.append(_greedy_death_wave(_cfg(s))) or strong.append(_greedy_death_wave(_foundry_cfg(s))):
			push_error("append failed")
	fresh.sort()
	strong.sort()
	print("FOUNDRY greedy4 median death wave fresh=%d foundry=%d" % [fresh[5], strong[5]])
	assert_int(strong[5]).is_greater_equal(fresh[5])


func _foundry_cfg(seed_value: int) -> SimConfig:
	var cfg: SimConfig = _cfg(seed_value)
	_set_foundry(cfg, "laser_output", 10, F_D_LASER)
	_set_foundry(cfg, "hull_integrity", 10, F_D_HULL)
	return cfg


func _greedy_death_wave(cfg: SimConfig) -> int:
	var w: SimWorld = SimWorld.new(cfg)
	var bot: PolicyBot = PolicyBot.new("greedy4")
	while not w.is_over() and w.tick < 60000:
		if w.tick % PolicyBot.THINK_INTERVAL == 0:
			bot.think(w)
		@warning_ignore("return_value_discarded")  # a draft takes the first offer (M4-15)
		PolicyBot.settle_draft(w)
		w.step()
	return w.run.death_wave


func _stat(s: StatBlock, id: String) -> float:
	var v: Variant = s.get(id)
	var f: float = v
	return f
