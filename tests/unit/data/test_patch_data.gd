class_name TestPatchData
extends GdUnitTestSuite
## Patch data (M4-13): patches.csv imported to PatchTable, importer rejections, string keys, draft tuning.

const TABLE_PATH: String = "res://src/data_gen/patch_table.tres"
const TUNING_PATH: String = "res://src/data_gen/sim_tuning.tres"
const STRINGS_CSV: String = "res://data/strings_en.csv"
const BAD_DIR: String = "res://tests/fixtures/data_bad"
const SCRATCH: String = "user://patch_data_test"
const REAL_DATA: String = "res://data"
const ALL_TABLES: PackedStringArray = [
	"sim_constants.csv",
	"enemies.csv",
	"run_upgrades.csv",
	"strings_en.csv",
	"number_suffixes.csv",
	"foundry.csv",
	"frames.csv",
	"wave_modes.csv",
	"patches.csv",
]
const IDS: PackedStringArray = [
	"patch_overcharge",
	"patch_plating",
	"patch_rate",
	"patch_extraction",
	"patch_regen",
	"patch_ceramic",
	"patch_t_glass",
	"patch_t_greed",
	"patch_t_hardhide",
]


func after_test() -> void:
	var dir: DirAccess = DirAccess.open(SCRATCH)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		for f: String in DirAccess.get_files_at(SCRATCH.path_join(sub)):
			assert_int(DirAccess.remove_absolute(SCRATCH.path_join(sub).path_join(f))).is_equal(OK)
		assert_int(DirAccess.remove_absolute(SCRATCH.path_join(sub))).is_equal(OK)


func _defs() -> Dictionary:
	var table: PatchTable = load(TABLE_PATH)
	var out: Dictionary = {}
	for d: PatchDef in table.defs:
		out[d.id] = d
	return out


func _check(id: String, stat: String, op: String, per_pick: float, max_picks: int) -> void:
	var d: PatchDef = _defs()[id]
	assert_str(d.stat).is_equal(stat)
	assert_str(d.op).is_equal(op)
	assert_float(d.per_pick).is_equal(per_pick)
	assert_int(d.max_picks).is_equal(max_picks)


func test_nine_defs_in_order() -> void:
	var table: PatchTable = load(TABLE_PATH)
	assert_int(table.defs.size()).is_equal(9)
	for i: int in IDS.size():
		assert_str(table.defs[i].id).is_equal(IDS[i])


func test_standard_values() -> void:
	_check("patch_overcharge", "laser_output", "bonus", 0.15, 5)
	_check("patch_plating", "hull_integrity", "bonus", 0.20, 5)
	_check("patch_rate", "cycle_rate", "bonus", 0.10, 5)
	_check("patch_extraction", "scrap_yield;data_yield", "bonus", 0.15, 5)
	_check("patch_regen", "nano_repair", "bonus", 0.50, 5)
	_check("patch_ceramic", "plating_pct", "add", 0.04, 5)
	var ext: PatchDef = _defs()["patch_extraction"]
	assert_array(Array(ext.stat_ids())).is_equal(["scrap_yield", "data_yield"])
	for id: String in IDS.slice(0, 6):
		var d: PatchDef = _defs()[id]
		assert_bool(d.is_gamble()).is_false()
		assert_str(d.cost_stat).is_empty()


func test_gamble_values() -> void:
	_check("patch_t_glass", "laser_output", "mult", 1.5, 1)
	_check("patch_t_greed", "data_yield", "mult", 1.8, 1)
	_check("patch_t_hardhide", "enemy_damage", "mult", 0.60, 1)
	var costs: Dictionary = {
		"patch_t_glass": ["hull_integrity", 0.70],
		"patch_t_greed": ["hull_integrity", 0.50],
		"patch_t_hardhide": ["laser_output", 0.60],
	}
	for id: String in costs:
		var d: PatchDef = _defs()[id]
		var want: Array = costs[id]
		assert_bool(d.is_gamble()).is_true()
		assert_str(d.cost_stat).is_equal(want[0])
		assert_str(d.cost_op).is_equal("mult")
		assert_float(d.cost_value).is_equal(want[1])


func test_every_string_key_exists() -> void:
	var keys: Dictionary = {}
	for r: PackedStringArray in _csv_rows(STRINGS_CSV):
		keys[r[0]] = true
	for d: PatchDef in (load(TABLE_PATH) as PatchTable).defs:
		assert_bool(keys.has(d.name_key)).override_failure_message("missing " + d.name_key).is_true()
		assert_bool(keys.has(d.desc_key)).override_failure_message("missing " + d.desc_key).is_true()
		if d.is_gamble():
			var cost_key: String = d.desc_key.trim_suffix(".desc") + ".cost"
			assert_bool(keys.has(cost_key)).override_failure_message("missing " + cost_key).is_true()
	for k: String in ["patch.cost_line", "draft.title", "draft.picks", "draft.gamble", "draft.note"]:
		assert_bool(keys.has(k)).override_failure_message("missing " + k).is_true()


func _csv_rows(path: String) -> Array[PackedStringArray]:
	var t: CsvTable = CsvTable.load_file(path)
	var out: Array[PackedStringArray] = []
	for r: int in t.rows.size():
		out.append(PackedStringArray([t.get_value(r, "key")]))
	return out


func test_draft_tuning_loads() -> void:
	var t: SimTuning = load(TUNING_PATH)
	assert_int(t.draft_first_wave).is_equal(10)
	assert_int(t.draft_interval).is_equal(10)
	assert_int(t.draft_interval_after).is_equal(50)
	assert_int(t.draft_interval_late).is_equal(25)
	assert_int(t.draft_offer_count).is_equal(3)
	assert_float(t.draft_mix_standard).is_equal(0.70)
	assert_float(t.draft_mix_gamble).is_equal(0.15)


func _expect_rejected(fixture: String, expected_text: String) -> void:
	var dir: String = SCRATCH.path_join(fixture.get_basename())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for t: String in ALL_TABLES:
		var src: String = BAD_DIR.path_join(fixture) if t == "patches.csv" else REAL_DATA.path_join(t)
		assert_int(DirAccess.copy_absolute(src, dir.path_join(t))).is_equal(OK)
	var importer: DataImporter = DataImporter.new()
	assert_bool(importer.run(dir, SCRATCH.path_join("out_" + fixture.get_basename()))).is_false()
	assert_str("\n".join(importer.errors)).contains(expected_text)


func test_importer_rejections_name_the_row() -> void:
	_expect_rejected("patches_duplicate_id.csv", "row 2 (patch_overcharge): duplicate id")
	_expect_rejected("patches_unknown_stat.csv", "row 1 (patch_overcharge): unknown stat 'laser_power'")
	_expect_rejected("patches_gamble_no_cost.csv", "row 1 (patch_t_glass) cost_stat: missing required value")
	_expect_rejected("patches_zero_max.csv", "row 1 (patch_overcharge): max_picks must be > 0")
	_expect_rejected("patches_missing_name_key.csv", "row 1 (patch_overcharge) name_key: missing required value")
