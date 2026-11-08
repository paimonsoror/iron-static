class_name TestUpgradePanelScene
extends GdUnitTestSuite
## Headless scene tests of UpgradeRow and UpgradePanel (M2-09, M2-10) bound to a real SimWorld.


func _world(best_wave: int = 0) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.best_wave_s1 = best_wave
	return SimWorld.new(cfg)


func _panel() -> UpgradePanel:
	var packed: PackedScene = load("res://src/ui/upgrade_panel.tscn")
	var panel: UpgradePanel = auto_free(packed.instantiate())
	add_child(panel)
	return panel


func test_row_scene_loads_applies_model_and_emits_buy_pressed() -> void:
	var packed: PackedScene = load("res://src/ui/upgrade_row.tscn")
	var row: UpgradeRow = auto_free(packed.instantiate())
	add_child(row)
	var w: SimWorld = _world()
	w.run_levels[0] = 24
	var p: UpgradePreview = UpgradeSystem.preview(w, 0, 1)
	row.apply(UpgradeRowModel.from_preview(p, p.affordable, p.level, w.config.upgrades[0]))
	assert_str((row.get_node("%LevelLabel") as Label).text).is_equal("L24")
	assert_str((row.get_node("%NameLabel") as Label).text).is_equal("LASER OUTPUT")
	assert_str((row.get_node("%ValueLabel") as Label).text).is_equal("34 > 52.5")
	var button: Button = row.get_node("%BuyButton")
	assert_str(button.theme_type_variation).is_equal(str(ThemeBuilder.VAR_BUTTON_UNAFFORDABLE))
	var hits: Array[int] = []
	row.buy_pressed.connect(func(i: int) -> void: hits.append(i))
	button.pressed.emit()
	assert_array(hits).is_equal([0])
	assert_bool(row.is_tooltip_visible()).is_false()


func test_panel_scene_loads_filters_rows_and_shows_hint() -> void:
	var panel: UpgradePanel = _panel()
	var w: SimWorld = _world(0)
	panel.bind(w)
	assert_str(panel.active_tab()).is_equal("arms")
	var visible_rows: Array[int] = []
	for i: int in w.config.upgrades.size():
		if panel.row_at(i).visible:
			visible_rows.append(i)
	assert_array(visible_rows).is_equal([0, 1])
	assert_str((panel.get_node("%HintLabel") as Label).text).is_equal("Next unlock at wave 3")
	assert_bool((panel.get_node("%HintLabel") as Label).visible).is_true()
	panel.set_tab("chassis")
	assert_bool(panel.row_at(5).visible).is_true()
	assert_bool(panel.row_at(0).visible).is_false()
	panel.set_tab("intel")
	assert_bool((panel.get_node("%IntelLabel") as Label).visible).is_true()
	assert_bool(panel.row_at(5).visible).is_false()


func test_buy_requested_carries_index_and_remembered_buy_mode() -> void:
	var panel: UpgradePanel = _panel()
	panel.bind(_world(99))
	var got: Array[Vector2i] = []
	panel.buy_requested.connect(func(i: int, c: int) -> void: got.append(Vector2i(i, c)))
	(panel.row_at(1).get_node("%BuyButton") as Button).pressed.emit()
	panel.set_buy_mode(100)
	panel.set_tab("systems")
	assert_int(panel.buy_mode()).is_equal(100)
	(panel.row_at(8).get_node("%BuyButton") as Button).pressed.emit()
	assert_array(got).is_equal([Vector2i(1, 1), Vector2i(8, 100)])
	assert_bool(panel.set_buy_mode(5)).is_false()


func test_refresh_follows_scrap_and_does_not_mutate_world() -> void:
	var panel: UpgradePanel = _panel()
	var w: SimWorld = _world(0)
	panel.bind(w)
	var before: String = w.state_hash()
	var button: Button = panel.row_at(1).get_node("%BuyButton")  # cycle_rate costs 25, start scrap 15
	assert_str(button.theme_type_variation).is_equal(str(ThemeBuilder.VAR_BUTTON_UNAFFORDABLE))
	w.economy.scrap = BigNum.from_float(1000.0)
	var mid: String = w.state_hash()
	panel.refresh()
	assert_str(button.theme_type_variation).is_equal("")
	assert_str(w.state_hash()).is_equal(mid)
	assert_str(before).is_not_equal(mid)


func test_panel_has_no_process_and_a_tenth_second_timer() -> void:
	var panel: UpgradePanel = _panel()
	assert_bool(panel.is_processing()).is_false()
	var timer: Timer = panel.get_node("%RefreshTimer")
	assert_float(timer.wait_time).is_equal(0.1)
	assert_bool(timer.is_stopped()).is_false()
