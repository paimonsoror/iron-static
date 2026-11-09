class_name TestFtueData
extends GdUnitTestSuite
## Ftue data (M4-25): ftue.csv imported to FtueTable, importer rejections name the row.

const BAD_DIR: String = "res://tests/fixtures/data_bad"
const SCRATCH: String = "user://ftue_data_test"
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
	"ftue.csv",
]


func after_test() -> void:
	var dir: DirAccess = DirAccess.open(SCRATCH)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		for f: String in DirAccess.get_files_at(SCRATCH.path_join(sub)):
			assert_int(DirAccess.remove_absolute(SCRATCH.path_join(sub).path_join(f))).is_equal(OK)
		assert_int(DirAccess.remove_absolute(SCRATCH.path_join(sub))).is_equal(OK)


func _expect_rejected(fixture: String, expected_text: String) -> void:
	var dir: String = SCRATCH.path_join(fixture.get_basename())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for t: String in ALL_TABLES:
		var src: String = BAD_DIR.path_join(fixture) if t == "ftue.csv" else REAL_DATA.path_join(t)
		assert_int(DirAccess.copy_absolute(src, dir.path_join(t))).is_equal(OK)
	var importer: DataImporter = DataImporter.new()
	assert_bool(importer.run(dir, SCRATCH.path_join("out_" + fixture.get_basename()))).is_false()
	assert_str("\n".join(importer.errors)).contains(expected_text)


func test_real_csv_loads_in_order() -> void:
	var table: FtueTable = load("res://src/data_gen/ftue_table.tres")
	assert_int(table.defs.size()).is_equal(12)
	assert_str(table.defs[0].id).is_equal("cold_open")
	assert_str(table.defs[1].target).is_equal("row:laser_output")
	assert_int(table.defs[1].max_runs).is_equal(1)


func test_importer_rejections_name_the_row() -> void:
	_expect_rejected("ftue_bad_trigger.csv", "row 2 (nap): unknown trigger 'nap_time'")
	_expect_rejected("ftue_bad_target.csv", "row 2 (up): bad target 'row:no_such_row'")
	_expect_rejected("ftue_unknown_key.csv", "row 2 (up): unknown text_key 'ftue.missing_key'")
	_expect_rejected("ftue_bad_max_runs.csv", "row 2 (up): max_runs must be 1 to 2")
	_expect_rejected("ftue_missing_cold_open.csv", "row 'cold_open' is missing")
