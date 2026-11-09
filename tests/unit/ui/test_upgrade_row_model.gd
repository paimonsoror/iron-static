class_name TestUpgradeRowModel
extends GdUnitTestSuite
## UpgradeRowModel (M2-09): texts and states from an UpgradePreview.


func _world() -> SimWorld:
	return SimWorld.new(SimConfigLoader.load_default(1))


func _row(w: SimWorld, id: String) -> int:
	for i: int in w.config.upgrades.size():
		if w.config.upgrades[i].id == id:
			return i
	return -1


func _model(w: SimWorld, id: String, count: int = 1) -> UpgradeRowModel:
	var i: int = _row(w, id)
	var p: UpgradePreview = UpgradeSystem.preview(w, i, count)
	return UpgradeRowModel.from_preview(p, p.affordable, p.level, w.config.upgrades[i])


func test_laser_output_level_24_glows_and_shows_resolver_next_value() -> void:
	var w: SimWorld = _world()
	w.run_levels[_row(w, "laser_output")] = 24
	var m: UpgradeRowModel = _model(w, "laser_output")
	assert_str(m.level_text).is_equal("L24")
	assert_bool(m.milestone_glow).is_true()
	# level 24 = 10 * (1 + 0.1 * 24) = 34; level 25 = 10 * 3.5 * 1.5 = 52.5 (StatResolver)
	assert_str(m.value_text).is_equal("34 > 52.5")
	assert_str(m.name_text).is_equal("LASER OUTPUT")


func test_glow_only_within_three_levels_of_milestone() -> void:
	var w: SimWorld = _world()
	var i: int = _row(w, "laser_output")
	var expected: Dictionary[int, bool] = {10: false, 21: false, 22: true, 24: true, 25: false, 47: true}
	for lvl: int in expected:
		w.run_levels[i] = lvl
		assert_bool(_model(w, "laser_output").milestone_glow).is_equal(expected[lvl])


func test_unaffordable_state_is_flagged_and_cost_is_formatted() -> void:
	var w: SimWorld = _world()  # start scrap 15 in the default tuning: cycle_rate costs 25
	var m: UpgradeRowModel = _model(w, "cycle_rate")
	assert_bool(m.affordable).is_false()
	assert_str(m.cost_text).is_equal("25")
	assert_str(m.value_text).is_equal("1 > 1.04")
	w.economy.scrap = BigNum.from_float(12400.0)
	assert_bool(_model(w, "cycle_rate").affordable).is_true()
	assert_str(_model(w, "laser_output", 10).cost_text).is_not_equal("")


func test_maxed_row_shows_max_and_no_cost() -> void:
	var w: SimWorld = _world()
	var i: int = _row(w, "cycle_rate")
	w.run_levels[i] = w.config.upgrades[i].l_cap
	var m: UpgradeRowModel = _model(w, "cycle_rate")
	assert_bool(m.maxed).is_true()
	assert_bool(m.affordable).is_false()
	assert_bool(m.milestone_glow).is_false()
	assert_str(m.cost_text).is_equal("MAX")
	assert_str(m.value_text).is_equal("5")


func test_names_resolve_through_strings_table_without_missing_keys() -> void:
	var w: SimWorld = _world()
	var before: int = Strings.missing_count
	for def: RunUpgradeDef in w.config.upgrades:
		assert_bool(Strings.has_key("upgrade." + def.id)).is_true()
		assert_str(Strings.get_text("upgrade." + def.id)).is_not_equal("upgrade." + def.id)
	assert_int(Strings.missing_count).is_equal(before)


func test_value_formats_by_row_kind() -> void:
	assert_str(UpgradeRowModel.format_value("crit_chance", 0.02)).is_equal("2.0%")
	assert_str(UpgradeRowModel.format_value("plating_pct", 0.5)).is_equal("50%")
	assert_str(UpgradeRowModel.format_value("reinvest", 0.0006)).is_equal("0.06%")
	assert_str(UpgradeRowModel.format_value("crit_mult", 1.5)).is_equal("x1.5")
	assert_str(UpgradeRowModel.format_value("optic_range", 24.4)).is_equal("24.4m")
	assert_str(UpgradeRowModel.format_value("laser_output", 1234.0)).is_equal("1.23K")
	assert_str(UpgradeRowModel.format_value("hull_integrity", 110.0)).is_equal("110")


func test_tooltip_has_formula_numbers_for_both_kinds() -> void:
	var w: SimWorld = _world()
	var d: String = _model(w, "laser_output").tooltip_text
	assert_str(d).contains("Base 10").contains("10%").contains("x1.5").contains("400").contains("Foundry")
	var c: String = _model(w, "cycle_rate").tooltip_text
	assert_str(c).contains("Base 1,").contains("+0.04").contains("100").contains("12")
	assert_str(c).contains("Foundry: --")


func test_foundry_tooltip_line_shows_the_real_contribution() -> void:
	var w: SimWorld = _world()
	var d: RunUpgradeDef = w.config.upgrades[_row(w, "laser_output")]
	var c: RunUpgradeDef = w.config.upgrades[_row(w, "cycle_rate")]
	assert_str(UpgradeRowModel.foundry_text(d, 0, 0.1)).is_equal("--")
	assert_str(UpgradeRowModel.foundry_text(d, 10, 0.1)).starts_with("F10  x")
	assert_str(UpgradeRowModel.foundry_text(c, 5, 0.0)).starts_with("F5  +")
	assert_str(UpgradeRowModel.tooltip_for(c, 5, 0.0)).not_contains("Foundry: --")
	assert_str(UpgradeRowModel.tooltip_for(c)).contains("Foundry: --")
