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
	row.buy_pressed.connect(func(i: int, c: int) -> void: hits.append(i * 1000 + c))
	button.button_down.emit()
	button.button_up.emit()
	assert_array(hits).is_equal([1])
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


func test_buy_requested_carries_index_and_count_of_a_tap() -> void:
	var panel: UpgradePanel = _panel()
	panel.bind(_world(99))
	var got: Array[Vector2i] = []
	panel.buy_requested.connect(func(i: int, c: int) -> void: got.append(Vector2i(i, c)))
	var b1: Button = panel.row_at(1).get_node("%BuyButton")
	b1.button_down.emit()
	b1.button_up.emit()
	panel.set_tab("systems")
	var b8: Button = panel.row_at(8).get_node("%BuyButton")
	b8.button_down.emit()
	b8.button_up.emit()
	assert_array(got).is_equal([Vector2i(1, 1), Vector2i(8, 1)])


func test_refresh_follows_scrap_and_does_not_mutate_world() -> void:
	var panel: UpgradePanel = _panel()
	var w: SimWorld = _world(0)
	w.economy.scrap = BigNum.from_float(10.0)  # below cycle_rate's 25 (start scrap is tuning data)
	panel.bind(w)
	var before: String = w.state_hash()
	var button: Button = panel.row_at(1).get_node("%BuyButton")
	assert_str(button.theme_type_variation).is_equal(str(ThemeBuilder.VAR_BUTTON_UNAFFORDABLE))
	w.economy.scrap = BigNum.from_float(1000.0)
	var mid: String = w.state_hash()
	panel.refresh()
	assert_str(button.theme_type_variation).is_equal(str(ThemeBuilder.VAR_BUTTON_AFFORDABLE))
	assert_str(w.state_hash()).is_equal(mid)
	assert_str(before).is_not_equal(mid)


func test_panel_has_no_process_and_a_tenth_second_timer() -> void:
	var panel: UpgradePanel = _panel()
	assert_bool(panel.is_processing()).is_false()
	var timer: Timer = panel.get_node("%RefreshTimer")
	assert_float(timer.wait_time).is_equal(0.1)
	assert_bool(timer.is_stopped()).is_false()


func test_code_driven_tab_switch_leaves_one_selected_and_no_buy_selector() -> void:
	var panel: UpgradePanel = _panel()
	panel.bind(_world(99))
	for id: String in ["chassis", "intel", "arms"]:
		assert_bool(panel.set_tab(id)).is_true()
	var tabs_on: int = 0
	for id: String in UpgradePanelModel.TAB_IDS:
		var tb: Button = panel.get_node("%TabBar/Tab_" + id)
		assert_bool(tb.focus_mode == Control.FOCUS_NONE).is_true()
		tabs_on += 1 if tb.button_pressed else 0
	assert_int(tabs_on).is_equal(1)
	assert_object(panel.get_node_or_null("%BuyBar")).is_null()


func test_row_cost_states_icon_and_maxed_plate() -> void:
	var panel: UpgradePanel = _panel()
	var w: SimWorld = _world(0)
	w.economy.scrap = BigNum.from_float(10.0)  # below cycle_rate's 25 (start scrap is tuning data)
	panel.bind(w)
	var row: UpgradeRow = panel.row_at(1)
	var button: Button = row.get_node("%BuyButton")
	assert_int(row.cost_state()).is_equal(UpgradeRow.CostState.LOCKED)
	assert_object(button.icon).is_same(UiKit.lock_icon())
	assert_object((row.get_node("%Icon") as TextureRect).texture).is_same(ArtSlots.texture("icon_cycle_rate"))
	w.economy.scrap = BigNum.from_float(1000.0)
	panel.refresh()
	assert_int(row.cost_state()).is_equal(UpgradeRow.CostState.AFFORDABLE)
	assert_object(button.icon).is_same(ArtSlots.texture("icon_cur_scrap"))
	assert_bool((row.get_node("%Fx") as RowFx).pulse).is_true()
	w.run_levels[1] = w.config.upgrades[1].l_cap
	panel.refresh()
	assert_int(row.cost_state()).is_equal(UpgradeRow.CostState.MAXED)
	assert_bool(button.disabled).is_true()
	assert_str(button.theme_type_variation).is_equal(str(ThemeBuilder.VAR_BUTTON_MAXED))
	assert_str(button.text).is_equal("MAX")
	assert_bool((row.get_node("%Fx") as RowFx).pulse).is_false()


func test_milestone_ring_follows_level_and_level_text_uses_number_font() -> void:
	var panel: UpgradePanel = _panel()
	var w: SimWorld = _world(0)
	w.run_levels[0] = 24
	panel.bind(w)
	var row: UpgradeRow = panel.row_at(0)
	assert_bool((row.get_node("%Fx") as RowFx).ring).is_true()
	w.run_levels[0] = 25
	panel.refresh()
	assert_bool((row.get_node("%Fx") as RowFx).ring).is_false()
	var level: Label = row.get_node("%LevelLabel")
	assert_str(str(level.theme_type_variation)).is_equal(str(ThemeBuilder.VAR_LABEL_NUMBER))
