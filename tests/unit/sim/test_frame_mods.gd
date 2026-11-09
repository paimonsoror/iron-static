class_name TestFrameMods
extends GdUnitTestSuite
## Frame stat modifiers and neutrality (M3-22).

# Re-pinned in M4-02 (the mode section is always hashed).
const PRE_M3_CONFIG_HASH: String = "8291a16da68c01b972b84a201d9ac4fc8ce4c7e03f19b0552286942849a2c8ac"


static func bulwark() -> FrameMods:
	var m: FrameMods = FrameMods.new()
	m.hull_mult = 1.6
	m.plating_add = 0.10
	m.nano_mult = 1.3
	m.cycle_mult = 0.75
	m.optic_mult = 0.92
	m.passive = FrameMods.PASSIVE_BASTION
	return m


static func striker() -> FrameMods:
	var m: FrameMods = FrameMods.new()
	m.cycle_mult = 1.4
	m.crit_add = 0.03
	m.laser_mult = 0.9
	m.hull_mult = 0.65
	m.nano_mult = 0.7
	m.passive = FrameMods.PASSIVE_OVERCLOCK
	return m


static func cfg_with(frame_id: String, mods: FrameMods, seed_value: int = 3) -> SimConfig:
	var cfg: SimConfig = SimConfigLoader.load_default(seed_value)
	cfg.frame = mods
	cfg.frame_id = frame_id
	return cfg


func test_neutral_frame_is_bit_identical_to_no_frame() -> void:
	var plain: SimWorld = SimWorld.new(SimConfigLoader.load_default(3))
	var cfg: SimConfig = cfg_with("vanguard", FrameMods.new())
	var van: SimWorld = SimWorld.new(cfg)
	assert_bool(FrameMods.new().is_neutral()).is_true()
	assert_str(ConfigHash.compute(cfg)).is_equal(PRE_M3_CONFIG_HASH)
	assert_str(van.state_hash()).is_equal(plain.state_hash())
	for k: int in 1500:
		plain.step()
		van.step()
	assert_str(van.state_hash()).is_equal(plain.state_hash())


func test_bulwark_start_stats_are_base_times_mods() -> void:
	var w: SimWorld = SimWorld.new(cfg_with("bulwark", bulwark()))
	assert_float(w.stats.hull_integrity).is_equal_approx(160.0, 1.0e-9)
	assert_float(w.cinder.max_hp).is_equal_approx(160.0, 1.0e-9)
	assert_float(w.stats.plating_pct).is_equal_approx(0.10, 1.0e-9)
	assert_float(w.stats.cycle_rate).is_equal_approx(0.75, 1.0e-9)
	assert_float(w.stats.optic_range).is_equal_approx(22.08, 1.0e-9)
	assert_float(w.stats.nano_repair).is_equal_approx(1.3, 1.0e-9)


func test_striker_start_stats() -> void:
	var w: SimWorld = SimWorld.new(cfg_with("striker", striker()))
	assert_float(w.stats.cycle_rate).is_equal_approx(1.40, 1.0e-9)
	assert_float(w.stats.crit_chance).is_equal_approx(0.05, 1.0e-9)
	assert_float(w.stats.hull_integrity).is_equal_approx(65.0, 1.0e-9)
	assert_float(w.stats.laser_output).is_equal_approx(9.0, 1.0e-9)
	assert_float(w.stats.nano_repair).is_equal_approx(0.7, 1.0e-9)


func test_cycle_multiplier_applies_after_the_hard_cap() -> void:
	var m: FrameMods = FrameMods.new()
	m.cycle_mult = 1.5
	var cfg: SimConfig = cfg_with("striker", m)
	var w: SimWorld = SimWorld.new(cfg)
	for i: int in cfg.upgrades.size():
		if cfg.upgrades[i].id == "cycle_rate":
			cfg.upgrades[i].hard_cap = 3.0  # levels alone cannot reach 12; lower the cap on this private copy
			w.run_levels[i] = cfg.upgrades[i].l_cap
	w.stats = w.resolve_stats()
	assert_float(w.stats.cycle_rate).is_equal_approx(3.0 * 1.5, 1.0e-9)


func test_frame_stats_include_foundry_on_top() -> void:
	var cfg: SimConfig = cfg_with("bulwark", bulwark())
	var lv: PackedInt32Array = PackedInt32Array()
	var ff: PackedFloat64Array = PackedFloat64Array()
	if lv.resize(cfg.upgrades.size()) != OK or ff.resize(cfg.upgrades.size()) != OK:
		push_error("resize failed")
	lv.fill(0)
	ff.fill(0.0)
	for i: int in cfg.upgrades.size():
		if cfg.upgrades[i].id == "hull_integrity":
			lv[i] = 10
			ff[i] = 0.06
	cfg.foundry_levels = lv
	cfg.foundry_f = ff
	var w: SimWorld = SimWorld.new(cfg)
	assert_float(w.stats.hull_integrity).is_equal_approx(100.0 * 1.6 * 1.6 * 1.25, 1.0e-9)


func test_frame_config_hash_differs_and_is_pinned_for_neutral() -> void:
	var b: String = ConfigHash.compute(cfg_with("bulwark", bulwark()))
	var s: String = ConfigHash.compute(cfg_with("striker", striker()))
	assert_str(b).is_not_equal(PRE_M3_CONFIG_HASH)
	assert_str(s).is_not_equal(b)
	assert_str(ConfigHash.compute(cfg_with("bulwark", bulwark()))).is_equal(b)


func test_unimplemented_frame_falls_back_to_vanguard() -> void:
	var m: FrameMods = FrameMods.new()
	m.hull_mult = 2.0
	m.passive = FrameMods.PASSIVE_SCRAP_TITHE
	m.implemented = false
	var cfg: SimConfig = cfg_with("salvager", m)
	SimWorld.log_frame_errors = false
	var w: SimWorld = SimWorld.new(cfg)
	SimWorld.log_frame_errors = true
	assert_str(cfg.frame_id).is_equal("vanguard")
	assert_float(w.stats.hull_integrity).is_equal_approx(100.0, 1.0e-9)
	assert_str(w.state_hash()).is_equal(SimWorld.new(SimConfigLoader.load_default(3)).state_hash())
	assert_str(ConfigHash.compute(cfg)).is_equal(PRE_M3_CONFIG_HASH)


func test_previews_include_frame_mods() -> void:
	var cfg: SimConfig = cfg_with("striker", striker())
	var w: SimWorld = SimWorld.new(cfg)
	for i: int in cfg.upgrades.size():
		if cfg.upgrades[i].id == "laser_output":
			var p: UpgradePreview = UpgradeSystem.preview(w, i, 1)
			assert_float(p.current_value).is_equal_approx(9.0, 1.0e-9)
			assert_float(p.next_value).is_equal_approx(9.9, 1.0e-9)
