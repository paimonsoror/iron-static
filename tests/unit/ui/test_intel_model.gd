class_name TestIntelModel
extends GdUnitTestSuite
## Intel Stats rows (M4-18): final values equal the resolver output, chains list Foundry, frame and patch factors,
## the panel hosts the rows in the INTEL tab, never mutates the sim, and the old stub key is unused in code.

const PATCH_TABLE: String = "res://src/data_gen/patch_table.tres"
const PANEL: PackedScene = preload("res://src/ui/upgrade_panel.tscn")


func _world(foundry_level: int = 0) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(5)
	var table: PatchTable = load(PATCH_TABLE)
	for d: PatchDef in table.defs:
		var copy: Variant = SimConfigLoader._clone(d)
		cfg.patches.append(copy)
	if foundry_level > 0:
		var lv: Dictionary = {}
		for u: RunUpgradeDef in cfg.upgrades:
			lv[u.id] = foundry_level
		SimConfigLoader.apply_foundry(cfg, lv)
	return SimWorld.new(cfg)


func _row(rows: Array[IntelRow], id: String) -> IntelRow:
	for r: IntelRow in rows:
		if r.id == id:
			return r
	return null


func _pick(w: SimWorld, id: String) -> void:
	for i: int in w.config.patches.size():
		if w.config.patches[i].id == id:
			assert_bool(PatchEffects.pick(w, i)).is_true()
			return
	fail("no patch " + id)


func test_laser_row_matches_resolver_and_lists_foundry_and_patch_factors() -> void:
	var w: SimWorld = _world(3)
	w.run_levels[0] = 4
	_pick(w, "patch_overcharge")
	var rows: Array[IntelRow] = IntelModel.build(w)
	var r: IntelRow = _row(rows, "laser_output")
	assert_object(r).is_not_null()
	assert_str(r.value_text).is_equal(IntelModel.format_value(IntelModel.Kind.NUM, w.stats.laser_output))
	var f: float = Curves.foundry_mult(3, w.config.foundry_f[0])
	assert_str(r.chain_text).contains("FOUNDRY " + NumberFormat.format_mult(f))
	assert_str(r.chain_text).contains("PATCH x1.09")
	assert_str(r.chain_text).contains("RUN ")
	assert_str(r.chain_text).starts_with("BASE 10")


func test_fresh_world_has_no_modifier_links_and_neutral_yield() -> void:
	var w: SimWorld = _world()
	var rows: Array[IntelRow] = IntelModel.build(w)
	assert_str(_row(rows, "laser_output").chain_text).is_equal("BASE 10")
	assert_str(_row(rows, "cycle_rate").value_text).is_equal("1/s")
	assert_str(_row(rows, "data_yield").value_text).is_equal("x1")
	assert_str(_row(rows, "data_yield").chain_text).is_equal("NO MODIFIERS")
	assert_object(_row(rows, "enemy_damage")).is_null()
	assert_object(_row(rows, "dps")).is_not_null()


func test_type_c_chain_and_dps() -> void:
	var w: SimWorld = _world()
	w.run_levels[1] = 10
	w.stats = w.resolve_stats()
	var rows: Array[IntelRow] = IntelModel.build(w)
	assert_str(_row(rows, "cycle_rate").chain_text).is_equal("BASE 1/s   RUN +0.4")
	assert_float(IntelModel.dps_of(w.stats)).is_equal_approx(w.stats.laser_output * 1.4 * (1.0 + 0.02 * 0.5), 1.0e-9)


func test_gamble_patch_adds_enemy_damage_row() -> void:
	var w: SimWorld = _world()
	_pick(w, "patch_t_hardhide")
	var rows: Array[IntelRow] = IntelModel.build(w)
	var r: IntelRow = _row(rows, "enemy_damage")
	assert_object(r).is_not_null()
	assert_str(r.value_text).is_equal(NumberFormat.format_mult(w.stats.enemy_damage))


func test_burn_hardening_row_shows_the_current_reduction() -> void:
	var w: SimWorld = _world()
	var r: IntelRow = _row(IntelModel.build(w), "burn_dr")
	assert_str(r.value_text).is_equal("NONE")
	assert_str(r.chain_text).is_equal("SKIN INTACT: FULL DAMAGE")
	w.cinder.band = 1
	assert_str(_row(IntelModel.build(w), "burn_dr").value_text).is_equal("-25%")
	w.cinder.band = 2
	assert_str(_row(IntelModel.build(w), "burn_dr").value_text).is_equal("-45%")
	w.cinder.band = 3
	var r3: IntelRow = _row(IntelModel.build(w), "burn_dr")
	assert_str(r3.value_text).is_equal("-65%")
	assert_str(r3.chain_text).is_equal("SKIN BURN BAND 3")


func test_build_never_mutates_the_sim() -> void:
	var w: SimWorld = _world(2)
	_pick(w, "patch_rate")
	var before: String = w.state_hash()
	var tick: int = w.tick
	var built: Array[IntelRow] = IntelModel.build(w)
	assert_int(built.size()).is_greater(0)
	assert_str(w.state_hash()).is_equal(before)
	assert_int(w.tick).is_equal(tick)


func test_intel_tab_hosts_the_stats_panel() -> void:
	var panel: UpgradePanel = PANEL.instantiate()
	var host: Control = auto_free(Control.new())
	host.size = Vector2(1080.0, 2400.0)
	add_child(host)
	host.add_child(panel)
	var w: SimWorld = _world()
	panel.bind(w)
	assert_bool(panel.set_tab("intel")).is_true()
	var intel: IntelPanel = panel.intel_panel()
	assert_object(intel).is_not_null()
	assert_bool(intel.is_visible_in_tree()).is_true()
	assert_int(intel.card_count()).is_greater(5)
	assert_str(intel.card_texts(0)[0]).is_equal("LASER OUTPUT")
	assert_bool(panel.set_tab("arms")).is_true()
	assert_bool(intel.is_visible_in_tree()).is_false()


func test_stub_key_is_unused_in_code() -> void:
	for dir: String in ["res://src/ui", "res://src/view", "res://src/core"]:
		for path: String in _gd_files(dir):
			(
				assert_bool(FileAccess.get_file_as_string(path).contains("panel.intel_stub"))
				. override_failure_message(path)
				. is_false()
			)


func _gd_files(dir: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var failed: bool = out.push_back(dir + "/" + f)
			assert_bool(failed).is_false()
	for d: String in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir + "/" + d))
	return out
