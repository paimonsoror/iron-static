class_name TestFrameData
extends GdUnitTestSuite
## Frame data (M3-21): frames.csv imported to FrameTable, design 11 table values, importer rejections.

const TABLE_PATH: String = "res://src/data_gen/frame_table.tres"
const BAD_DIR: String = "res://tests/fixtures/data_bad"
const SCRATCH: String = "user://frame_data_test"
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


func _frame(id: String) -> FrameDef:
	var table: FrameTable = load(TABLE_PATH)
	for d: FrameDef in table.defs:
		if d.id == id:
			return d
	return null


func test_five_rows_in_order_and_vanguard_neutral() -> void:
	var table: FrameTable = load(TABLE_PATH)
	var ids: PackedStringArray = []
	for d: FrameDef in table.defs:
		ids.append(d.id)
	assert_array(ids).is_equal(["vanguard", "bulwark", "striker", "salvager", "longshot"])
	var v: FrameDef = _frame("vanguard")
	assert_bool(v.implemented).is_true()
	assert_str(v.passive).is_equal("none")
	assert_int(v.unlock_best_wave).is_equal(0)
	for value: float in [v.hull_mult, v.nano_mult, v.cycle_mult, v.optic_mult, v.laser_mult]:
		assert_float(value).is_equal(1.0)
	for value: float in [v.plating_add, v.crit_add]:
		assert_float(value).is_equal(0.0)


func test_bulwark_and_striker_match_design() -> void:
	var b: FrameDef = _frame("bulwark")
	assert_float(b.hull_mult).is_equal(1.6)
	assert_float(b.plating_add).is_equal(0.10)
	assert_float(b.nano_mult).is_equal(1.3)
	assert_float(b.cycle_mult).is_equal(0.75)
	assert_float(b.optic_mult).is_equal(0.92)
	assert_str(b.passive).is_equal("bastion")
	assert_int(b.unlock_best_wave).is_equal(8)
	var s: FrameDef = _frame("striker")
	assert_float(s.cycle_mult).is_equal(1.4)
	assert_float(s.crit_add).is_equal(0.03)
	assert_float(s.laser_mult).is_equal(0.9)
	assert_float(s.hull_mult).is_equal(0.65)
	assert_float(s.nano_mult).is_equal(0.7)
	assert_str(s.passive).is_equal("overclock")
	assert_int(s.unlock_best_wave).is_equal(15)


func test_m6_frames_are_not_implemented() -> void:
	for id: String in ["salvager", "longshot"]:
		var d: FrameDef = _frame(id)
		assert_bool(d.implemented).is_false()
		assert_str(d.tag).is_equal("M6")
	assert_float(_frame("salvager").scrap_mult).is_equal(1.25)
	assert_float(_frame("longshot").crit_mult_mult).is_equal(2.0)


func test_string_keys_resolve() -> void:
	var table: FrameTable = load(TABLE_PATH)
	var before: int = Strings.missing_count
	for d: FrameDef in table.defs:
		for key: String in [d.name_key, d.role_key, d.passive_key, "frame.passive_desc." + d.id]:
			assert_bool(Strings.has_key(key)).is_true()
			assert_str(Strings.get_text(key)).is_not_equal(key)
	assert_int(Strings.missing_count).is_equal(before)


func _expect_rejected(fixture: String, expected_text: String) -> void:
	var dir: String = SCRATCH.path_join(fixture.get_basename())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for t: String in ALL_TABLES:
		var src: String = BAD_DIR.path_join(fixture) if t == "frames.csv" else REAL_DATA.path_join(t)
		assert_int(DirAccess.copy_absolute(src, dir.path_join(t))).is_equal(OK)
	var importer: DataImporter = DataImporter.new()
	assert_bool(importer.run(dir, SCRATCH.path_join("out_" + fixture.get_basename()))).is_false()
	assert_str("\n".join(importer.errors)).contains(expected_text)


func test_importer_rejections() -> void:
	_expect_rejected("frames_bad_passive.csv", "unknown passive 'bogus'")
	_expect_rejected("frames_vanguard_not_neutral.csv", "vanguard must be neutral")
	_expect_rejected("frames_implemented_unknown_passive.csv", "sim does not know")
