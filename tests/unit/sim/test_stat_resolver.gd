class_name TestStatResolver
extends GdUnitTestSuite
## StatResolver against GDD 02 sections 5 and 7 (M2-03).

var _defs: Array[RunUpgradeDef]


func before_test() -> void:
	_defs = SimConfigLoader.load_default(1).upgrades


func _idx(id: String) -> int:
	for i: int in _defs.size():
		if _defs[i].id == id:
			return i
	return -1


func _levels(id: String, level: int) -> PackedInt32Array:
	var lv: PackedInt32Array = PackedInt32Array()
	var n: int = lv.resize(_defs.size())
	assert_int(n).is_equal(OK)
	lv[_idx(id)] = level
	return lv


func _resolve(id: String, level: int) -> StatBlock:
	return StatBlock.from_resolver(_defs, _levels(id, level))


func test_level_zero_equals_base() -> void:
	var s: StatBlock = StatBlock.from_resolver(_defs, PackedInt32Array())
	assert_float(s.laser_output).is_equal(10.0)
	assert_float(s.cycle_rate).is_equal(1.0)
	assert_float(s.crit_chance).is_equal(0.02)
	assert_float(s.crit_mult).is_equal(1.5)
	assert_float(s.optic_range).is_equal(24.0)
	assert_float(s.hull_integrity).is_equal(100.0)
	assert_float(s.nano_repair).is_equal(1.0)
	assert_float(s.plating_pct).is_equal(0.0)
	assert_float(s.scrap_yield).is_equal(1.0)
	assert_float(s.reinvest).is_equal(0.0)


func test_matches_from_base() -> void:
	var cfg: SimConfig = SimConfig.new()
	cfg.upgrades = _defs
	var a: StatBlock = StatBlock.from_base(cfg)
	var b: StatBlock = StatBlock.from_resolver(_defs, PackedInt32Array())
	assert_float(a.laser_output).is_equal(b.laser_output)
	assert_float(a.hull_integrity).is_equal(b.hull_integrity)
	assert_float(a.reinvest).is_equal(b.reinvest)


func test_laser_output_levels() -> void:
	assert_float(_resolve("laser_output", 1).laser_output).is_equal_approx(11.0, 1e-9)
	assert_float(_resolve("laser_output", 25).laser_output).is_equal_approx(52.5, 1e-9)
	var expect: float = 10.0 * (1.0 + 0.1 * 400.0) * pow(1.5, 16.0)
	var got: float = _resolve("laser_output", 400).laser_output
	assert_float(absf(got - expect) / expect).is_less(1e-9)


func test_levels_clamped_to_l_cap() -> void:
	var cap: float = _resolve("laser_output", 400).laser_output
	assert_float(_resolve("laser_output", 9999).laser_output).is_equal(cap)
	assert_float(_resolve("scrap_yield", 500).scrap_yield).is_equal_approx(3.0, 1e-9)


func test_type_c_values_and_caps() -> void:
	assert_float(_resolve("cycle_rate", 100).cycle_rate).is_equal_approx(5.0, 1e-9)
	assert_float(_resolve("scrap_yield", 100).scrap_yield).is_equal_approx(3.0, 1e-9)
	assert_float(_resolve("crit_chance", 98).crit_chance).is_less_equal(0.85)
	assert_float(_resolve("plating_pct", 99).plating_pct).is_less_equal(0.90)


func test_hard_caps_clamp_forced_rows() -> void:
	var rows: Array[RunUpgradeDef] = []
	for id: String in ["cycle_rate", "crit_chance", "plating_pct"]:
		var src: RunUpgradeDef = _defs[_idx(id)]
		var d: RunUpgradeDef = RunUpgradeDef.new()
		d.id = src.id
		d.kind = src.kind
		d.base = src.base
		d.l_cap = src.l_cap
		d.has_hard_cap = src.has_hard_cap
		d.hard_cap = src.hard_cap
		d.step = 1.0
		rows.append(d)
	var lv: PackedInt32Array = PackedInt32Array([50, 50, 50])
	var s: StatBlock = StatResolver.resolve(rows, lv, PackedInt32Array(), PackedFloat64Array(), null)
	assert_float(s.cycle_rate).is_equal(12.0)
	assert_float(s.crit_chance).is_equal(0.85)
	assert_float(s.plating_pct).is_equal(0.90)


func test_no_hard_cap_row_unclamped() -> void:
	assert_float(_resolve("crit_mult", 150).crit_mult).is_equal_approx(9.0, 1e-9)


func test_foundry_type_d() -> void:
	var fl: PackedInt32Array = _levels("laser_output", 25)
	var ff: PackedFloat64Array = PackedFloat64Array()
	var n: int = ff.resize(_defs.size())
	assert_int(n).is_equal(OK)
	ff[_idx("laser_output")] = 0.06
	var s: StatBlock = StatResolver.resolve(_defs, PackedInt32Array(), fl, ff, null)
	# foundry_mult(25, 0.06) = (1 + 1.5) * 1.75 = 4.375
	assert_float(s.laser_output / 10.0).is_equal_approx(4.4, 0.044)


func test_foundry_zero_is_exact_identity() -> void:
	assert_float(Curves.foundry_mult(0, 0.06)).is_equal(1.0)
	assert_float(Curves.foundry_mult(0, 0.0)).is_equal(1.0)


func test_foundry_type_c_capped_at_half_l_cap() -> void:
	var fl: PackedInt32Array = _levels("scrap_yield", 999)
	var s: StatBlock = StatResolver.resolve(_defs, PackedInt32Array(), fl, PackedFloat64Array(), null)
	# F_cap = 50, f_inc = 0.02 -> 1.0 + 1.0
	assert_float(s.scrap_yield).is_equal_approx(2.0, 1e-9)


func test_external_mults() -> void:
	var m: ExternalMults = ExternalMults.new()
	m.laser_output_mult = 2.0
	m.scrap_yield_mult = 1.5
	m.reinvest_add = 0.01
	m.crit_chance_add = 2.0
	var s: StatBlock = StatResolver.resolve(_defs, PackedInt32Array(), PackedInt32Array(), PackedFloat64Array(), m)
	assert_float(s.laser_output).is_equal_approx(20.0, 1e-9)
	assert_float(s.scrap_yield).is_equal_approx(1.5, 1e-9)
	assert_float(s.reinvest).is_equal_approx(0.01, 1e-9)
	assert_float(s.crit_chance).is_equal(0.85)


func test_levels_to_next_milestone() -> void:
	assert_int(StatResolver.levels_to_next_milestone(0)).is_equal(25)
	assert_int(StatResolver.levels_to_next_milestone(24)).is_equal(1)
	assert_int(StatResolver.levels_to_next_milestone(25)).is_equal(25)
	assert_int(StatResolver.levels_to_next_milestone(26)).is_equal(24)


func test_patch_only_stats_are_neutral_without_mults_and_follow_external_mults() -> void:
	var plain: StatBlock = StatResolver.resolve(
		_defs, PackedInt32Array(), PackedInt32Array(), PackedFloat64Array(), null
	)
	assert_float(plain.data_yield).is_equal(1.0)
	assert_float(plain.enemy_damage).is_equal(1.0)
	var m: ExternalMults = ExternalMults.new()
	m.scale_stat("data_yield", 1.8)
	m.scale_stat("enemy_damage", 0.6)
	m.scale_stat("enemy_damage", 0.6)
	m.add_stat("plating_pct", 0.04)
	var c: ExternalMults = m.copy()
	var s: StatBlock = StatResolver.resolve(_defs, PackedInt32Array(), PackedInt32Array(), PackedFloat64Array(), c)
	assert_float(s.data_yield).is_equal_approx(1.8, 1e-12)
	assert_float(s.enemy_damage).is_equal_approx(0.36, 1e-12)
	assert_float(s.plating_pct).is_equal_approx(0.04, 1e-12)
