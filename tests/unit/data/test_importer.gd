class_name TestImporter
extends GdUnitTestSuite
## DataImporter: validation rules (bad fixtures), idempotence, committed output matches the CSV.

const REAL_DATA: String = "res://data"
const BAD_DIR: String = "res://tests/fixtures/data_bad"
const EMPTY_DIR: String = "res://tests/fixtures/data_empty"
const GEN_DIR: String = "res://src/data_gen"
const SCRATCH: String = "user://import_test"
const TABLES: PackedStringArray = ["sim_constants.csv", "enemies.csv", "run_upgrades.csv", "strings_en.csv"]


func after_test() -> void:
	_remove_dir(SCRATCH)


## Real data dir copied to `name` under the scratch folder, with `overlay` (a fixture) replacing `table`.
func _make_data_dir(dir_name: String, table: String, overlay: String) -> String:
	var dir: String = SCRATCH.path_join(dir_name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for t: String in TABLES:
		var src: String = overlay if (t == table and not overlay.is_empty()) else REAL_DATA.path_join(t)
		assert_int(DirAccess.copy_absolute(src, dir.path_join(t))).is_equal(OK)
	return dir


func _import(data_dir: String, out_name: String) -> DataImporter:
	var importer: DataImporter = DataImporter.new()
	importer.run(data_dir, SCRATCH.path_join(out_name))
	return importer


func _expect_rejected(table: String, fixture: String, expected_text: String) -> void:
	var data_dir: String = _make_data_dir("data_" + fixture.get_basename(), table, BAD_DIR.path_join(fixture))
	var out_dir: String = SCRATCH.path_join("out_" + fixture.get_basename())
	var importer: DataImporter = DataImporter.new()
	assert_bool(importer.run(data_dir, out_dir)).is_false()
	assert_bool(importer.errors.is_empty()).is_false()
	assert_str("\n".join(importer.errors)).contains(expected_text)
	assert_bool(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(out_dir))).is_false()


func test_enemy_rules() -> void:
	_expect_rejected("enemies.csv", "enemies_unknown_column.csv", "unknown column 'extra'")
	_expect_rejected("enemies.csv", "enemies_missing_value.csv", "speed: missing required value")
	_expect_rejected("enemies.csv", "enemies_duplicate_id.csv", "duplicate id")
	_expect_rejected("enemies.csv", "enemies_negative_weight.csv", "spawn_weight must be >= 0")
	_expect_rejected("enemies.csv", "enemies_non_finite.csv", "not a finite number")
	_expect_rejected("enemies.csv", "enemies_nan.csv", "dmg_mult")
	_expect_rejected("enemies.csv", "enemies_not_a_number.csv", "is not a number")


func test_upgrade_rules() -> void:
	_expect_rejected("run_upgrades.csv", "upgrades_unknown_column.csv", "unknown column 'bogus'")
	_expect_rejected("run_upgrades.csv", "upgrades_missing_value.csv", "c0: missing required value")
	_expect_rejected("run_upgrades.csv", "upgrades_duplicate_id.csv", "duplicate id")
	_expect_rejected("run_upgrades.csv", "upgrades_g_not_above_one.csv", "g must be > 1")
	_expect_rejected("run_upgrades.csv", "upgrades_l_cap_zero.csv", "l_cap must be > 0")
	_expect_rejected("run_upgrades.csv", "upgrades_negative_c0.csv", "c0 must be >= 0")
	_expect_rejected("run_upgrades.csv", "upgrades_bad_kind.csv", "kind must be D or C")
	_expect_rejected("run_upgrades.csv", "upgrades_non_finite.csv", "not a finite number")


func test_constant_rules() -> void:
	_expect_rejected("sim_constants.csv", "constants_unknown_key.csv", "unknown key")
	_expect_rejected("sim_constants.csv", "constants_missing_keys.csv", "missing key 'arena_radius'")
	_expect_rejected("sim_constants.csv", "constants_bad_value.csv", "is not an integer")
	_expect_rejected("sim_constants.csv", "constants_non_finite.csv", "not a finite number")
	_expect_rejected("sim_constants.csv", "constants_bad_source.csv", "source must be")
	_expect_rejected("sim_constants.csv", "constants_duplicate_key.csv", "duplicate key")


func test_malformed_csv_reports_parse_error() -> void:
	_expect_rejected("enemies.csv", "malformed_row.csv", "has 1 fields, header has 2")
	_expect_rejected("enemies.csv", "malformed_fields.csv", "has 3 fields, header has 14")


func test_missing_table_file_is_rejected() -> void:
	var dir: String = SCRATCH.path_join("data_missing")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var importer: DataImporter = DataImporter.new()
	assert_bool(importer.run(dir, SCRATCH.path_join("out_missing"))).is_false()
	assert_str("\n".join(importer.errors)).contains("file not found")


func test_importer_is_idempotent() -> void:
	var data_dir: String = _make_data_dir("data_ok", "", "")
	var a: DataImporter = _import(data_dir, "out_a")
	var b: DataImporter = _import(data_dir, "out_b")
	assert_str("\n".join(a.errors)).is_empty()
	assert_str("\n".join(b.errors)).is_empty()
	assert_int(a.files.size()).is_equal(1 + 5 + 1 + 10 + 1 + 1)
	for n: String in a.files:
		var ha: String = FileAccess.get_sha256(SCRATCH.path_join("out_a").path_join(n))
		var hb: String = FileAccess.get_sha256(SCRATCH.path_join("out_b").path_join(n))
		assert_str(ha).is_not_empty()
		assert_str(ha).is_equal(hb)


func test_committed_output_matches_csv() -> void:
	var data_dir: String = _make_data_dir("data_cur", "", "")
	var importer: DataImporter = _import(data_dir, "out_cur")
	assert_str("\n".join(importer.errors)).is_empty()
	for n: String in importer.files:
		var committed: String = FileAccess.get_file_as_string(GEN_DIR.path_join(n))
		var expected: String = importer.files[n]
		assert_str(committed).override_failure_message("src/data_gen/%s is stale: rerun import_data.ps1" % n).is_equal(
			expected
		)
	var present: PackedStringArray = DirAccess.get_files_at(GEN_DIR)
	var tres_count: int = 0
	for n: String in present:
		if n.ends_with(".tres"):
			tres_count += 1
	assert_int(tres_count).is_equal(importer.files.size())


func test_output_has_no_uid_paths_or_timestamps() -> void:
	var tuning: String = FileAccess.get_file_as_string(GEN_DIR.path_join("sim_tuning.tres"))
	assert_bool(tuning.contains("uid=")).is_false()
	assert_bool(tuning.contains("C:/")).is_false()
	assert_bool(tuning.ends_with("\n")).is_true()
	assert_bool(tuning.contains("\r")).is_false()


func test_empty_tables_are_valid() -> void:
	var importer: DataImporter = DataImporter.new()
	assert_bool(importer.run(EMPTY_DIR, SCRATCH.path_join("out_empty"))).is_true()
	assert_bool(importer.files.has("enemy_table.tres")).is_true()
	assert_bool(importer.files.has("upgrade_table.tres")).is_true()
	assert_int(importer.files.size()).is_equal(3)


func test_stale_generated_files_are_removed() -> void:
	var data_dir: String = _make_data_dir("data_stale", "", "")
	var out_dir: String = SCRATCH.path_join("out_stale")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var stale: FileAccess = FileAccess.open(out_dir.path_join("enemy_old_id.tres"), FileAccess.WRITE)
	stale.store_string("x")
	stale.close()
	var importer: DataImporter = DataImporter.new()
	assert_bool(importer.run(data_dir, out_dir)).is_true()
	assert_bool(FileAccess.file_exists(out_dir.path_join("enemy_old_id.tres"))).is_false()


func _remove_dir(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_remove_dir(path.path_join(sub))
	for f: String in dir.get_files():
		var rm_file: Error = dir.remove(f)
		assert_int(rm_file).is_equal(OK)
	var rm_dir: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	assert_int(rm_dir).is_equal(OK)
