class_name TestWaveModeData
extends GdUnitTestSuite
## Wave mode data (M4-01): wave_modes.csv imported to WaveModeTable, importer rejections.

const TABLE_PATH: String = "res://src/data_gen/wave_mode_table.tres"
const BAD_DIR: String = "res://tests/fixtures/data_bad"
const SCRATCH: String = "user://wave_mode_data_test"
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
]


func after_test() -> void:
	var dir: DirAccess = DirAccess.open(SCRATCH)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		for f: String in DirAccess.get_files_at(SCRATCH.path_join(sub)):
			assert_int(DirAccess.remove_absolute(SCRATCH.path_join(sub).path_join(f))).is_equal(OK)
		assert_int(DirAccess.remove_absolute(SCRATCH.path_join(sub))).is_equal(OK)


func _mode(id: String) -> WaveModeDef:
	var table: WaveModeTable = load(TABLE_PATH)
	for d: WaveModeDef in table.defs:
		if d.id == id:
			return d
	return null


func test_real_csv_has_two_modes_with_spec_values() -> void:
	var table: WaveModeTable = load(TABLE_PATH)
	assert_int(table.defs.size()).is_equal(2)
	var t: WaveModeDef = _mode("timed")
	assert_bool(t.implemented).is_true()
	assert_int(t.unlock_best_timed_wave).is_equal(0)
	assert_float(t.backstop_s).is_equal(0.0)
	assert_float(t.reward_mult).is_equal(1.0)
	assert_int(t.sort).is_equal(0)
	var p: WaveModeDef = _mode("purge")
	assert_bool(p.implemented).is_true()
	assert_int(p.unlock_best_timed_wave).is_equal(20)
	assert_float(p.backstop_s).is_equal(60.0)
	assert_float(p.reward_mult).is_equal(1.0)
	assert_int(p.sort).is_equal(1)


func _expect_rejected(fixture: String, expected_text: String) -> void:
	var dir: String = SCRATCH.path_join(fixture.get_basename())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for t: String in ALL_TABLES:
		var src: String = BAD_DIR.path_join(fixture) if t == "wave_modes.csv" else REAL_DATA.path_join(t)
		assert_int(DirAccess.copy_absolute(src, dir.path_join(t))).is_equal(OK)
	var importer: DataImporter = DataImporter.new()
	assert_bool(importer.run(dir, SCRATCH.path_join("out_" + fixture.get_basename()))).is_false()
	assert_str("\n".join(importer.errors)).contains(expected_text)


func test_importer_rejections_name_the_row() -> void:
	_expect_rejected("wave_modes_duplicate_id.csv", "row 2 (timed): duplicate id")
	_expect_rejected("wave_modes_missing_timed.csv", "row 'timed' is missing")
	_expect_rejected("wave_modes_purge_no_backstop.csv", "row 2 (purge): backstop_s must be > 0")
	_expect_rejected("wave_modes_negative_reward.csv", "row 2 (purge): reward_mult must be > 0")
	_expect_rejected("wave_modes_duplicate_sort.csv", "row 2 (purge): duplicate sort 0")
	_expect_rejected("wave_modes_timed_locked.csv", "row 1 (timed): timed must be implemented and unlocked at 0")
