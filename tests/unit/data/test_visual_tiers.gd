class_name TestVisualTiers
extends GdUnitTestSuite
## Visual tiers (VT-1): data/visual_tiers.csv imported to VisualTierTable, the importer's row-naming rejections and
## the pure VisualTierModel lookups.

const TABLE_PATH: String = "res://src/data_gen/visual_tier_table.tres"
const SCRATCH: String = "user://vt_import"
const STATS: PackedStringArray = ["laser_output", "hull_integrity", "plating_pct", "nano_repair"]
const THRESHOLDS: Dictionary = {
	"laser_output": [0, 5, 12, 25],
	"hull_integrity": [0, 5, 12, 25],
	"nano_repair": [0, 5, 12, 25],
	"plating_pct": [3, 8, 16, 30],
}


func after_test() -> void:
	var dir: DirAccess = DirAccess.open(SCRATCH)
	if dir != null:
		for n: String in dir.get_files():
			@warning_ignore("return_value_discarded")
			dir.remove(n)


func _defs() -> Array[VisualTierDef]:
	var table: VisualTierTable = load(TABLE_PATH)
	return table.defs


## Runs the importer on the real data dir with visual_tiers.csv replaced by `csv_text`; output is never written
## for a bad table, and the good-table run writes under the scratch folder.
func _import(csv_text: String) -> DataImporter:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))
	for t: String in ["sim_constants.csv", "enemies.csv", "run_upgrades.csv", "strings_en.csv"]:
		assert_int(DirAccess.copy_absolute("res://data/" + t, SCRATCH.path_join(t))).is_equal(OK)
	var f: FileAccess = FileAccess.open(SCRATCH.path_join("visual_tiers.csv"), FileAccess.WRITE)
	f.store_string(csv_text)
	f.close()
	var importer: DataImporter = DataImporter.new()
	@warning_ignore("return_value_discarded")
	importer.run(SCRATCH, SCRATCH.path_join("out"))
	return importer


func _rows() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for l: String in FileAccess.get_file_as_string("res://data/visual_tiers.csv").split("\n", false):
		if not l.begins_with("#"):
			out.append(l)
	return out


func _with(old: String, new: String) -> String:
	return "\n".join(_rows()).replace(old, new) + "\n"


func test_table_matches_the_spec_thresholds() -> void:
	var defs: Array[VisualTierDef] = _defs()
	assert_int(defs.size()).is_equal(16)
	for stat: String in STATS:
		var want: Array = THRESHOLDS[stat]
		var got: Array = []
		for d: VisualTierDef in defs:
			if d.upgrade == stat:
				got.append(d.threshold)
		assert_array(got).is_equal(want)


func test_thresholds_strictly_increase_per_stat_and_tiers_run_1_to_4() -> void:
	var last_threshold: Dictionary = {}
	var last_tier: Dictionary = {}
	for d: VisualTierDef in _defs():
		var prev: int = last_threshold.get(d.upgrade, -1)
		var prev_tier: int = last_tier.get(d.upgrade, 0)
		assert_int(d.threshold).is_greater(prev)
		assert_int(d.tier).is_equal(prev_tier + 1)
		last_threshold[d.upgrade] = d.threshold
		last_tier[d.upgrade] = d.tier
	for stat: String in STATS:
		assert_int(last_tier[stat]).is_equal(4)


func test_every_label_and_banner_key_exists_and_stats_are_run_upgrades() -> void:
	var table: UpgradeTable = load("res://src/data_gen/upgrade_table.tres")
	var ids: PackedStringArray = PackedStringArray()
	for u: RunUpgradeDef in table.defs:
		ids.append(u.id)
	for d: VisualTierDef in _defs():
		assert_bool(Strings.has_key(d.label_key)).is_true()
		assert_bool(d.banner_key.is_empty() or Strings.has_key(d.banner_key)).is_true()
		assert_bool(ids.has(d.upgrade)).is_true()
	assert_bool(Strings.has_key("vt.next")).is_true()
	assert_bool(Strings.has_key("vt.top")).is_true()


func test_params_are_readable_and_unknown_keys_fall_back() -> void:
	var laser4: VisualTierDef = _defs()[3]
	assert_str(laser4.id).is_equal("laser_4")
	assert_float(laser4.param("glow")).is_equal(100.0)
	assert_float(laser4.param("rim")).is_equal_approx(0.3, 0.0001)
	assert_float(laser4.param("nope", 7.0)).is_equal(7.0)


func test_model_mk1_below_first_threshold_and_steps() -> void:
	var m: VisualTierModel = VisualTierModel.shared()
	assert_int(m.tier_for("laser_output", 0)).is_equal(1)
	assert_int(m.tier_for("laser_output", 4)).is_equal(1)
	assert_int(m.tier_for("laser_output", 5)).is_equal(2)
	assert_int(m.tier_for("laser_output", 11)).is_equal(2)
	assert_int(m.tier_for("laser_output", 12)).is_equal(3)
	assert_int(m.tier_for("laser_output", 25)).is_equal(4)
	assert_int(m.tier_for("laser_output", 400)).is_equal(4)
	assert_int(m.tier_for("plating_pct", 2)).is_equal(0)
	assert_int(m.tier_for("plating_pct", 3)).is_equal(1)
	assert_int(m.tier_for("plating_pct", 30)).is_equal(4)
	assert_int(m.tier_for("cycle_rate", 50)).is_equal(0)
	assert_str(m.mark_key("laser_output", 0)).is_equal("vt.mark.1")
	assert_str(m.mark_key("plating_pct", 2)).is_equal("")
	assert_str(m.mark_key("plating_pct", 8)).is_equal("vt.plated.2")
	assert_int(m.max_tier("hull_integrity")).is_equal(4)
	assert_bool(m.has_tiers("cycle_rate")).is_false()


func test_model_next_threshold_and_top_mark_has_none() -> void:
	var m: VisualTierModel = VisualTierModel.shared()
	assert_int(m.next_threshold("laser_output", 0)).is_equal(5)
	assert_int(m.next_threshold("laser_output", 5)).is_equal(12)
	assert_int(m.next_threshold("laser_output", 24)).is_equal(25)
	assert_int(m.next_threshold("laser_output", 25)).is_equal(-1)
	assert_int(m.next_threshold("plating_pct", 0)).is_equal(3)
	assert_int(m.next_threshold("plating_pct", 30)).is_equal(-1)
	assert_int(m.next_threshold("crit_chance", 1)).is_equal(-1)


func test_model_progress_fraction() -> void:
	var m: VisualTierModel = VisualTierModel.shared()
	assert_float(m.progress("laser_output", 0)).is_equal(0.0)
	assert_float(m.progress("laser_output", 5)).is_equal(0.0)
	assert_float(m.progress("laser_output", 8)).is_equal_approx(3.0 / 7.0, 0.0001)
	assert_float(m.progress("laser_output", 25)).is_equal(1.0)
	assert_float(m.progress("plating_pct", 0)).is_equal(0.0)
	assert_float(m.progress("plating_pct", 2)).is_equal_approx(2.0 / 3.0, 0.0001)


func test_importer_accepts_the_committed_csv() -> void:
	var importer: DataImporter = _import(_with("", ""))
	assert_str("\n".join(importer.errors)).is_empty()


func test_importer_rejects_non_increasing_threshold_naming_the_row() -> void:
	var importer: DataImporter = _import(
		_with("laser_3,laser_output,3,MK III,level,12", "laser_3,laser_output,3,MK III,level,5")
	)
	assert_str("\n".join(importer.errors)).contains("row 3 (laser_3): thresholds must increase")


func test_importer_rejects_unknown_stat_missing_key_and_short_tier_count() -> void:
	var e1: DataImporter = _import(_with("hull_2,hull_integrity", "hull_2,warp_core"))
	assert_str("\n".join(e1.errors)).contains("row 6 (hull_2): unknown upgrade 'warp_core'")
	var e2: DataImporter = _import(_with("vt.mark.3,vt.banner.nano", "vt.mark.9,vt.banner.nano"))
	assert_str("\n".join(e2.errors)).contains("unknown label_key 'vt.mark.9'")
	var rows: PackedStringArray = _rows()
	rows.remove_at(rows.size() - 1)
	var e3: DataImporter = _import("\n".join(rows) + "\n")
	assert_str("\n".join(e3.errors)).contains("nano_repair: needs 4 tiers, has 3")
