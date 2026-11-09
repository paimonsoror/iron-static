class_name TestMigrations
extends GdUnitTestSuite
## MigrationChain framework with a synthetic two-step table (M3-04).


static func v1_to_v2(doc: Dictionary) -> Dictionary:
	var out: Dictionary = doc.duplicate(true)
	out["gold"] = out.get("coins", 0)  # rename; keeps the old key (data kept one version)
	out["order"] = "2"
	return out


static func v2_to_v3(doc: Dictionary) -> Dictionary:
	var out: Dictionary = doc.duplicate(true)
	var order: Variant = out.get("order", "")
	out["order"] = str(order) + "3"
	out["added"] = true
	return out


func _table() -> Array[Callable]:
	var t: Array[Callable] = [Callable(TestMigrations, "v1_to_v2"), Callable(TestMigrations, "v2_to_v3")]
	return t


func test_runs_steps_in_order_and_sets_version() -> void:
	var res: Dictionary = MigrationChain.run({"schema_version": 1, "coins": 5}, 1, 3, _table())
	assert_bool(res["ok"]).is_true()
	var doc: Dictionary = res["doc"]
	assert_str(doc["order"]).is_equal("23")
	assert_int(doc["schema_version"]).is_equal(3)
	assert_bool(doc["added"]).is_true()


func test_rename_keeps_old_field() -> void:
	var res: Dictionary = MigrationChain.run({"schema_version": 1, "coins": 5}, 1, 2, _table())
	var doc: Dictionary = res["doc"]
	assert_int(doc["gold"]).is_equal(5)
	assert_int(doc["coins"]).is_equal(5)


func test_input_is_not_mutated() -> void:
	var src: Dictionary = {"schema_version": 1, "coins": 5}
	var res: Dictionary = MigrationChain.run(src, 1, 3, _table())
	assert_bool(res["ok"]).is_true()
	assert_bool(src.has("gold")).is_false()
	assert_int(src["schema_version"]).is_equal(1)


func test_already_current_is_identity() -> void:
	var src: Dictionary = {"schema_version": 3, "gold": 1}
	var res: Dictionary = MigrationChain.run(src, 3, 3, _table())
	assert_bool(res["ok"]).is_true()
	assert_dict(res["doc"]).is_equal(src)
	var cur: Dictionary = res["doc"]
	var again: Dictionary = MigrationChain.run(cur, 3, 3, _table())
	assert_dict(again["doc"]).is_equal(src)


func test_downgrade_is_refused() -> void:
	var res: Dictionary = MigrationChain.run({"schema_version": 3}, 3, 2, _table())
	assert_bool(res["ok"]).is_false()
	assert_str(res["error"]).contains("downgrade")


func test_gap_is_refused() -> void:
	var t: Array[Callable] = [Callable(TestMigrations, "v1_to_v2")]
	var res: Dictionary = MigrationChain.run({"schema_version": 1}, 1, 3, t)
	assert_bool(res["ok"]).is_false()
	assert_str(res["error"]).contains("v2 -> v3")
	var none: Array[Callable] = []
	var res2: Dictionary = MigrationChain.run({"schema_version": 1}, 1, 2, none)
	assert_bool(res2["ok"]).is_false()


func test_real_v1_to_v2_copies_best_wave_to_timed() -> void:
	var src: Dictionary = {"schema_version": 1, "profile": {"best_wave": {"1": 14}, "flux": 3}}
	var res: Dictionary = SaveSchema.upgrade(src, 1)
	assert_bool(res["ok"]).is_true()
	var doc: Dictionary = res["doc"]
	assert_int(doc["schema_version"]).is_equal(2)
	var prof: Dictionary = doc["profile"]
	assert_dict(prof["best_wave_by_mode"]).is_equal({"timed": {"1": 14}})
	assert_array(prof["modes_unlocked"]).is_equal(["timed"])
	assert_str(prof["last_mode"]).is_equal("timed")
	assert_dict(prof["best_wave"]).is_equal({"1": 14})  # kept one version
	assert_int(prof["flux"]).is_equal(3)
	var old: Dictionary = src["profile"]
	assert_bool(old.has("last_mode")).is_false()  # input not mutated


func test_real_v1_to_v2_keeps_existing_v2_fields_and_survives_a_bad_profile() -> void:
	var keep: Dictionary = {"profile": {"last_mode": "purge", "modes_unlocked": ["timed", "purge"]}}
	var out: Dictionary = MigrateV1ToV2.apply(keep)
	var prof: Dictionary = out["profile"]
	assert_str(prof["last_mode"]).is_equal("purge")
	assert_dict(prof["best_wave_by_mode"]).is_equal({"timed": {}})
	assert_dict(MigrateV1ToV2.apply({"profile": 5})).is_equal({"profile": 5})


func test_real_table_matches_current_version() -> void:
	assert_int(SaveSchema.migrations().size()).is_equal(SaveSchema.CURRENT - 1)
	var res: Dictionary = SaveSchema.upgrade({"schema_version": SaveSchema.CURRENT}, SaveSchema.CURRENT)
	assert_bool(res["ok"]).is_true()
