class_name TestUiStringKeys
extends GdUnitTestSuite
## Guards against a missing UI string key (M2-16): building the HUD with the upgrade panel and the results
## overlay against a world with all 10 rows visible must not bump `Strings.missing_count`.


func test_hud_and_results_overlay_use_only_known_keys() -> void:
	var before: int = Strings.missing_count
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.best_wave_s1 = 12
	var w := SimWorld.new(cfg)
	var hud: Hud = auto_free((load("res://src/ui/hud.tscn") as PackedScene).instantiate())
	add_child(hud)
	hud.refresh(w, 0.0)
	var panel: UpgradePanel = hud.upgrade_panel()
	for tab: String in UpgradePanelModel.TAB_IDS:
		panel.set_tab(tab)
		panel.refresh()
	for mode: int in UpgradePanelModel.BUY_MODES:
		panel.set_buy_mode(mode)
	hud.set_paused(true)
	hud.set_paused(false)
	var overlay: ResultsOverlay = auto_free((load("res://src/ui/results_overlay.tscn") as PackedScene).instantiate())
	add_child(overlay)
	var c := RunController.new()
	c.start_run(1)
	c.fast_forward(60000)
	overlay.show_results(c.world)
	assert_int(Strings.missing_count).is_equal(before)


func test_every_run_upgrade_has_a_name_key() -> void:
	var table: CsvTable = CsvTable.load_file("res://data/run_upgrades.csv")
	assert_int(table.rows.size()).is_greater(0)
	for r: int in table.rows.size():
		var key: String = "upgrade." + table.get_value(r, "id")
		assert_bool(Strings.has_key(key)).is_true()
