class_name TestStrings
extends GdUnitTestSuite
## Strings loader (data/strings_en.csv).


func test_lookup_fill_and_missing_key_counting() -> void:
	assert_str(Strings.get_text("tab.arms")).is_equal("ARMS")
	assert_str(Strings.fill1("panel.next_unlock", "n", "7")).is_equal("Next unlock at wave 7")
	assert_str(Strings.fill("row.value", {"a": "1", "b": "2"})).is_equal("1 > 2")
	var before: int = Strings.missing_count
	assert_str(Strings.get_text("no.such.key")).is_equal("no.such.key")
	assert_int(Strings.missing_count).is_equal(before + 1)
	assert_int(Strings.key_count()).is_greater(30)


func test_generated_table_ships_and_matches_csv() -> void:
	# data/ is gdignored so only the generated .tres reaches the APK: it must exist and equal the CSV.
	assert_bool(ResourceLoader.exists(Strings.GEN_PATH)).is_true()
	var res: Resource = load(Strings.GEN_PATH)
	assert_bool(res is StringTable).is_true()
	var gen: StringTable = res
	var csv: CsvTable = CsvTable.load_file(Strings.PATH)
	assert_int(gen.keys.size()).is_equal(csv.rows.size())
	for r: int in csv.rows.size():
		assert_str(gen.keys[r]).is_equal(csv.get_value(r, "key"))
		assert_str(gen.texts[r]).is_equal(csv.get_value(r, "text"))


func test_wave_mode_keys_are_non_empty() -> void:
	var keys: PackedStringArray = [
		"mode.timed",
		"mode.purge",
		"mode.timed.desc",
		"mode.purge.desc",
		"mode.picker.title",
		"mode.locked",
		"mode.progress",
		"mode.unlocked_toast",
		"mode.chip",
		"results.mode",
		"results.best_mode",
		"hud.mode_purge_left",
		"home.best_mode",
	]
	var before: int = Strings.missing_count
	for key: String in keys:
		assert_bool(Strings.has_key(key)).is_true()
		assert_str(Strings.get_text(key)).is_not_empty()
	assert_str(Strings.fill1("mode.locked", "n", "20")).is_equal("Reach wave 20 in TIMED to unlock")
	assert_str(Strings.fill("home.best_mode", {"name": "PURGE", "n": "7"})).is_equal("BEST PURGE 7")
	assert_int(Strings.missing_count).is_equal(before)
