class_name TestUpgradeDescData
extends GdUnitTestSuite
## Every run upgrade and every Foundry row has a plain description string `upgrade.<id>.desc`, so a new upgrade cannot
## ship without one (the run tooltip and the Foundry tooltip both lead with it).

const MAX_LEN: int = 70


func _ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for def: RunUpgradeDef in SimConfigLoader.load_default(1).upgrades:
		ids.append(def.id)
	for fdef: FoundryDef in SimConfigLoader.load_foundry_defs():
		if not ids.has(fdef.id):
			ids.append(fdef.id)
	return ids


func test_every_upgrade_and_foundry_row_has_a_short_description() -> void:
	var ids: PackedStringArray = _ids()
	assert_int(ids.size()).is_greater_equal(10)
	for id: String in ids:
		var key: String = "upgrade." + id + ".desc"
		assert_bool(Strings.has_key(key)).override_failure_message("missing string " + key).is_true()
		var text: String = UpgradeRowModel.upgrade_desc(id)
		assert_str(text).override_failure_message(key + " is empty").is_not_empty()
		assert_int(text.length()).override_failure_message(key + " is longer than %d" % MAX_LEN).is_less_equal(MAX_LEN)
		assert_str(text).override_failure_message(key + " has no sentence end").ends_with(".")
