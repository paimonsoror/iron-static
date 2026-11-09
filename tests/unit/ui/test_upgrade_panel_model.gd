class_name TestUpgradePanelModel
extends GdUnitTestSuite
## UpgradePanelModel (M2-10): tab filtering, hint line, tab state.


func _defs() -> Array[RunUpgradeDef]:
	return SimConfigLoader.load_default(1).upgrades


func _ids(defs: Array[RunUpgradeDef], idx: PackedInt32Array) -> Array[String]:
	var out: Array[String] = []
	for i: int in idx:
		out.append(defs[i].id)
	return out


func test_tabs_with_everything_unlocked() -> void:
	var defs: Array[RunUpgradeDef] = _defs()
	var vis: PackedByteArray = UnlockRules.visible(defs, 999)
	var arms: Array[String] = _ids(defs, UpgradePanelModel.rows_for_tab(defs, vis, "arms"))
	assert_array(arms).is_equal(["laser_output", "cycle_rate", "crit_chance", "crit_mult", "optic_range"])
	var chassis: Array[String] = _ids(defs, UpgradePanelModel.rows_for_tab(defs, vis, "chassis"))
	assert_array(chassis).is_equal(["hull_integrity", "nano_repair", "plating_pct"])
	var systems: Array[String] = _ids(defs, UpgradePanelModel.rows_for_tab(defs, vis, "systems"))
	assert_array(systems).is_equal(["scrap_yield", "reinvest"])
	assert_int(UpgradePanelModel.rows_for_tab(defs, vis, "intel").size()).is_equal(0)
	assert_str(UpgradePanelModel.hint_text(defs, 999)).is_equal("")


func test_best_wave_zero_shows_four_starting_rows_and_wave_3_hint() -> void:
	var defs: Array[RunUpgradeDef] = _defs()
	var vis: PackedByteArray = UnlockRules.visible(defs, 0)
	var total: int = 0
	for tab: String in ["arms", "chassis", "systems"]:
		total += UpgradePanelModel.rows_for_tab(defs, vis, tab).size()
	assert_int(total).is_equal(4)
	var arms: Array[String] = _ids(defs, UpgradePanelModel.rows_for_tab(defs, vis, "arms"))
	assert_array(arms).is_equal(["laser_output", "cycle_rate"])
	assert_str(UpgradePanelModel.hint_text(defs, 0)).is_equal("Next unlock at best wave 3")
	assert_str(UpgradePanelModel.hint_text(defs, 3)).is_equal("Next unlock at best wave 5")


func test_tab_state_toggle() -> void:
	var m := UpgradePanelModel.new()
	assert_str(m.active_tab).is_equal("arms")
	assert_bool(m.set_tab("systems")).is_true()
	assert_bool(m.set_tab("nope")).is_false()
	assert_str(m.active_tab).is_equal("systems")
