class_name TestIntelWaveModel
extends GdUnitTestSuite
## Intel Wave rows (M4-19): wave and mode, clock or quota, boss and draft countdowns, N(w), stale count and the enemy
## mix equal the planner and sim values; the model never mutates the sim; the sub-tabs switch the two panels.

const PANEL: PackedScene = preload("res://src/ui/upgrade_panel.tscn")


func _world(mode: String = "timed", wave: int = 1) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(5)
	cfg.wave_mode = mode
	cfg.purge_backstop_ticks = 600 if mode == "purge" else 0
	var w := SimWorld.new(cfg)
	w.wave = wave
	return w


func _row(rows: Array[IntelRow], id: String) -> IntelRow:
	for r: IntelRow in rows:
		if r.id == id:
			return r
	return null


func test_wave_10_timed_shows_slots_boss_and_draft_now() -> void:
	var w: SimWorld = _world("timed", 10)
	var rows: Array[IntelRow] = IntelWaveModel.build(w)
	assert_str(_row(rows, "wave").value_text).is_equal("10")
	assert_str(_row(rows, "wave").chain_text).is_equal("MODE: TIMED")
	assert_int(WavePlanner.slots_for_wave(w, 10)).is_equal(13)
	assert_str(_row(rows, "slots").value_text).is_equal("13")
	assert_str(_row(rows, "boss").value_text).is_equal("NOW")
	assert_str(_row(rows, "draft").value_text).is_equal("NOW")
	assert_int(IntelWaveModel.boss_in(w)).is_equal(0)
	assert_int(DraftSystem.waves_until_draft(w)).is_equal(0)
	assert_str(_row(rows, "time_left").value_text).is_equal("24s")
	assert_object(_row(rows, "quota")).is_null()


func test_wave_7_boss_in_three_and_draft_in_three() -> void:
	var w: SimWorld = _world("timed", 7)
	var rows: Array[IntelRow] = IntelWaveModel.build(w)
	assert_str(_row(rows, "boss").value_text).is_equal("IN 3 WAVES")
	assert_str(_row(rows, "draft").value_text).is_equal("IN 3 WAVES")
	assert_str(_row(rows, "draft").chain_text).is_equal("AT THE END OF WAVE 10")
	w.wave = 9
	assert_str(_row(IntelWaveModel.build(w), "boss").value_text).is_equal("IN 1 WAVE")


func test_after_the_wave_10_draft_the_next_is_wave_15() -> void:
	var w: SimWorld = _world("timed", 11)
	assert_int(DraftSystem.waves_until_draft(w)).is_equal(4)  # wave 15
	assert_int(IntelWaveModel.boss_in(w)).is_equal(9)


func test_no_patches_means_no_draft_row() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(5)
	cfg.patches.clear()
	var w := SimWorld.new(cfg)
	assert_int(DraftSystem.waves_until_draft(w)).is_equal(-1)
	assert_object(_row(IntelWaveModel.build(w), "draft")).is_null()


func test_mix_rows_equal_planner_weights() -> void:
	var w: SimWorld = _world("timed", 10)
	var weights: PackedFloat64Array = WavePlanner.weights_for_wave(w, 10)
	var total: float = 0.0
	for x: float in weights:
		total += x
	var rows: Array[IntelRow] = IntelWaveModel.build(w)
	var seen: int = 0
	for i: int in w.config.enemies.size():
		var r: IntelRow = _row(rows, "type_" + w.config.enemies[i].id)
		if w.type_is_boss[i] != 0:
			assert_str(r.value_text).is_equal("BOSS")
		elif weights[i] > 0.0:
			assert_str(r.value_text).is_equal(NumberFormat.format_percent(weights[i] / total))
			seen += 1
		else:
			assert_object(r).is_null()
	assert_int(seen).is_greater(1)
	w.wave = 6
	assert_object(_row(IntelWaveModel.build(w), "type_boss_hulk")).is_null()


func test_stale_count_matches_hand_built_world() -> void:
	var w: SimWorld = _world("timed", 4)
	var a: int = w.debug_spawn_enemy(0, 5.0, 0.0)
	var b: int = w.debug_spawn_enemy(0, 6.0, 0.0)
	@warning_ignore("return_value_discarded")
	w.debug_spawn_enemy(0, 7.0, 0.0)
	w.enemies.stale[a] = 1
	w.enemies.stale[b] = 1
	assert_int(w.stale_count()).is_equal(2)
	assert_str(_row(IntelWaveModel.build(w), "stale").value_text).is_equal("2")
	w.enemies.alive[b] = 0
	assert_int(w.stale_count()).is_equal(1)


func test_purge_shows_quota_and_backstop() -> void:
	var w: SimWorld = _world("purge", 3)
	for _k: int in 100:
		w.step()
	var rows: Array[IntelRow] = IntelWaveModel.build(w)
	assert_object(_row(rows, "time_left")).is_null()
	var q: IntelRow = _row(rows, "quota")
	assert_str(q.value_text).is_equal("%d LEFT" % PurgeClock.remaining_quota(w))
	assert_str(q.chain_text).is_equal("BACKSTOP IN %ds" % ceili(float(600 - w.wave_tick) / 30.0))
	assert_str(_row(rows, "wave").chain_text).is_equal("MODE: PURGE")


func test_build_does_not_mutate_the_sim() -> void:
	var w: SimWorld = _world("timed", 10)
	var before: String = w.state_hash()
	assert_int(IntelWaveModel.build(w).size()).is_greater(4)
	assert_str(w.state_hash()).is_equal(before)


func test_hub_switches_between_stats_and_wave_panels() -> void:
	var panel: UpgradePanel = PANEL.instantiate()
	var host: Control = auto_free(Control.new())
	host.size = Vector2(1080.0, 2400.0)
	add_child(host)
	host.add_child(panel)
	var w: SimWorld = _world("timed", 7)
	panel.bind(w)
	assert_bool(panel.set_tab("intel")).is_true()
	var hub: IntelHub = panel.intel_hub()
	assert_str(hub.active_sub()).is_equal("stats")
	assert_bool(hub.stats_panel().is_visible_in_tree()).is_true()
	assert_bool(hub.wave_panel().visible).is_false()
	assert_float(hub.sub_button("wave").custom_minimum_size.y).is_greater_equal(148.0)
	assert_bool(hub.set_sub("wave")).is_true()
	assert_bool(hub.set_sub("nope")).is_false()
	hub.wave_panel().refresh()
	assert_bool(hub.stats_panel().visible).is_false()
	assert_int(hub.wave_panel().card_count()).is_greater(5)
	assert_str(hub.wave_panel().card_texts(0)[0]).is_equal("CURRENT WAVE")
	assert_bool(panel.set_tab("arms")).is_true()
	assert_bool(hub.visible).is_false()
