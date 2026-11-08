class_name TestFoundryData
extends GdUnitTestSuite
## Foundry data (M3-05): foundry.csv imported to FoundryTable, rules vs run_upgrades.csv, importer rejections.

const TABLE_PATH: String = "res://src/data_gen/foundry_table.tres"
const BAD_DIR: String = "res://tests/fixtures/data_bad"
const SCRATCH: String = "user://foundry_data_test"
const REAL_DATA: String = "res://data"
const ALL_TABLES: PackedStringArray = [
	"sim_constants.csv",
	"enemies.csv",
	"run_upgrades.csv",
	"strings_en.csv",
	"number_suffixes.csv",
	"foundry.csv",
	"frames.csv",
]


func after_test() -> void:
	var dir: DirAccess = DirAccess.open(SCRATCH)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		for f: String in DirAccess.get_files_at(SCRATCH.path_join(sub)):
			assert_int(DirAccess.remove_absolute(SCRATCH.path_join(sub).path_join(f))).is_equal(OK)
		assert_int(DirAccess.remove_absolute(SCRATCH.path_join(sub))).is_equal(OK)


func _table() -> FoundryTable:
	return load(TABLE_PATH)


func _upgrade(id: String) -> RunUpgradeDef:
	var upgrades: UpgradeTable = load("res://src/data_gen/upgrade_table.tres")
	for d: RunUpgradeDef in upgrades.defs:
		if d.id == id:
			return d
	return null


func test_rows_order_kinds_and_caps() -> void:
	var defs: Array[FoundryDef] = _table().defs
	assert_int(defs.size()).is_equal(4)
	var ids: PackedStringArray = []
	var kinds: String = ""
	var caps: Array[int] = []
	for d: FoundryDef in defs:
		ids.append(d.id)
		kinds += d.kind
		caps.append(d.f_cap)
	assert_array(ids).is_equal(["laser_output", "cycle_rate", "hull_integrity", "nano_repair"])
	assert_str(kinds).is_equal("DCDD")
	assert_array(caps).is_equal([200, 50, 200, 200])
	assert_float(defs[0].f).is_equal(0.06)
	assert_float(defs[3].f).is_equal(0.05)
	assert_float(defs[1].f).is_equal(0.0)


func test_type_c_row_follows_generic_rule() -> void:
	for d: FoundryDef in _table().defs:
		var run: RunUpgradeDef = _upgrade(d.id)
		assert_object(run).is_not_null()
		assert_str(d.kind).is_equal(run.kind)
		if d.kind == "C":
			assert_int(d.f_cap).is_equal(maxi(1, floori(float(run.l_cap) / 2.0)))
			assert_float(d.fc0).is_equal(2.0 * run.c0)
			assert_float(d.fg).is_equal(run.g)


func test_cumulative_cost_matches_gdd() -> void:
	var d: FoundryDef = _table().defs[0]
	var total: float = 0.0
	for level: int in 10:
		total += ceilf(d.fc0 * pow(d.fg, float(level)))
	# GDD 1.2: about 319 data to F10 (closed form 20 x (1.1^10 - 1) / 0.1); the sum of ceils is 323.
	assert_float(total).is_equal_approx(319.0, 319.0 * 0.02)
	assert_float(ceilf(d.fc0)).is_equal(20.0)
	assert_float(ceilf(_table().defs[3].fc0)).is_equal(25.0)


func _data_dir(dir_name: String, table: String, overlay: String) -> String:
	var dir: String = SCRATCH.path_join(dir_name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for t: String in ALL_TABLES:
		var src: String = BAD_DIR.path_join(overlay) if t == table else REAL_DATA.path_join(t)
		assert_int(DirAccess.copy_absolute(src, dir.path_join(t))).is_equal(OK)
	return dir


func _expect_rejected(fixture: String, expected_text: String) -> void:
	var data_dir: String = _data_dir(fixture.get_basename(), "foundry.csv", fixture)
	var importer: DataImporter = DataImporter.new()
	assert_bool(importer.run(data_dir, SCRATCH.path_join("out_" + fixture.get_basename()))).is_false()
	assert_str("\n".join(importer.errors)).contains(expected_text)


func test_importer_rejections() -> void:
	_expect_rejected("foundry_unknown_id.csv", "unknown id")
	_expect_rejected("foundry_kind_mismatch.csv", "kind differs")
	_expect_rejected("foundry_duplicate_id.csv", "duplicate id")


func test_committed_output_matches_csv() -> void:
	var data_dir: String = _data_dir("real", "", "")
	var out_dir: String = SCRATCH.path_join("out_real")
	var importer: DataImporter = DataImporter.new()
	assert_bool(importer.run(data_dir, out_dir)).is_true()
	for f: String in ["foundry_table.tres", "foundry_laser_output.tres", "foundry_cycle_rate.tres"]:
		var fresh: String = FileAccess.get_file_as_string(out_dir.path_join(f))
		var committed: String = FileAccess.get_file_as_string("res://src/data_gen".path_join(f))
		assert_str(fresh).is_equal(committed)
