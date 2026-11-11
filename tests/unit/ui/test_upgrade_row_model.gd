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
	var w: SimWorld = _world()
	w.economy.scrap = BigNum.from_float(10.0)  # below cycle_rate's 25 (start scrap is tuning data)
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


func _model_with_foundry(w: SimWorld, id: String, f_level: int, f: float) -> UpgradeRowModel:
	var i: int = _row(w, id)
	var p: UpgradePreview = UpgradeSystem.preview(w, i, 1)
	return UpgradeRowModel.from_preview(p, p.affordable, p.level, w.config.upgrades[i], f_level, f, w.config.tuning)


func test_tooltip_leads_with_description_then_now_and_next() -> void:
	var w: SimWorld = _world()
	var i: int = _row(w, "plating_pct")
	w.run_levels[i] = 2
	var lines: PackedStringArray = _model(w, "plating_pct").tooltip_text.split("\n")
	assert_str(lines[0]).is_equal("Blocks this share of the damage from every hit on Cinder.")
	assert_str(lines[1]).is_equal("Now 12% -> next 18%")
	assert_str(lines[2]).starts_with("Base 0.0%")
	var d: PackedStringArray = _model(w, "laser_output").tooltip_text.split("\n")
	assert_str(d[0]).is_equal(UpgradeRowModel.upgrade_desc("laser_output"))
	assert_str(d[1]).is_equal("Now 10 -> next 11")
	assert_str(d[2]).starts_with("Base 10")


func test_now_next_matches_the_row_values_with_foundry_levels() -> void:
	var w: SimWorld = _world()
	var n: int = w.config.upgrades.size()
	w.config.foundry_levels = PackedInt32Array()
	w.config.foundry_f = PackedFloat64Array()
	for k: int in n:
		w.config.foundry_levels.append(5)
		w.config.foundry_f.append(0.1)
	for id: String in ["cycle_rate", "laser_output"]:
		var i: int = _row(w, id)
		w.run_levels[i] = 3
		var def: RunUpgradeDef = w.config.upgrades[i]
		var cur: String = UpgradeRowModel.format_value(
			id, StatResolver.value_at(def, 3, 5, 0.1, 1.0, 0.0, w.config.tuning)
		)
		var nxt: String = UpgradeRowModel.format_value(
			id, StatResolver.value_at(def, 4, 5, 0.1, 1.0, 0.0, w.config.tuning)
		)
		var m: UpgradeRowModel = _model_with_foundry(w, id, 5, 0.1)
		var lines: PackedStringArray = m.tooltip_text.split("\n")
		assert_str(lines[0]).is_equal(UpgradeRowModel.upgrade_desc(id))
		assert_str(lines[1]).is_equal("Now " + cur + " -> next " + nxt)
		assert_str(m.value_text).is_equal(cur + " > " + nxt)  # the row shows the same pair
		assert_str(m.tooltip_text).contains("Foundry: F5")


func test_now_next_says_max_at_the_level_cap_and_at_the_hard_limit() -> void:
	var w: SimWorld = _world()
	var i: int = _row(w, "cycle_rate")
	w.run_levels[i] = w.config.upgrades[i].l_cap
	var capped: PackedStringArray = _model(w, "cycle_rate").tooltip_text.split("\n")
	assert_str(capped[1]).is_equal("Now 5 (max)")
	# A hard limit below the level cap: the next level changes nothing, so the line reads max, not "5 -> 5".
	w.config.upgrades[i].hard_cap = 1.04
	w.run_levels[i] = 1
	var limited: PackedStringArray = _model(w, "cycle_rate").tooltip_text.split("\n")
	assert_str(limited[1]).is_equal("Now 1.04 (max)")
	var below: PackedStringArray = _model(w, "crit_chance").tooltip_text.split("\n")
	assert_str(below[1]).starts_with("Now 2.0% -> next ")


func test_tooltip_hold_time_scales_with_text_and_is_capped() -> void:
	assert_float(RowTooltip.hold_seconds("")).is_equal(RowTooltip.TOOLTIP_S)
	assert_float(RowTooltip.hold_seconds("x".repeat(100))).is_greater(RowTooltip.hold_seconds("x".repeat(20)))
	assert_float(RowTooltip.hold_seconds("x".repeat(5000))).is_equal(RowTooltip.TOOLTIP_MAX_S)
	var w: SimWorld = _world()
	var longest: float = RowTooltip.hold_seconds(_model(w, "laser_output").tooltip_text)
	assert_float(longest).is_greater_equal(6.0).is_less_equal(RowTooltip.TOOLTIP_MAX_S)
