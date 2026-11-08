class_name TestUnlockRules
extends GdUnitTestSuite
## UnlockRules gates from data/run_upgrades.csv (M2-04).


func _defs() -> Array[RunUpgradeDef]:
	return SimConfigLoader.load_default(1).upgrades


func _visible_ids(best: int) -> Array[String]:
	var defs: Array[RunUpgradeDef] = _defs()
	var vis: PackedByteArray = UnlockRules.visible(defs, best)
	var ids: Array[String] = []
	for i: int in defs.size():
		if vis[i] == 1:
			ids.append(defs[i].id)
	return ids


func test_best_wave_0() -> void:
	var ids: Array[String] = _visible_ids(0)
	assert_int(ids.size()).is_equal(4)
	for id: String in ["laser_output", "cycle_rate", "hull_integrity", "nano_repair"]:
		assert_bool(ids.has(id)).is_true()


func test_gates_add_rows() -> void:
	assert_bool(_visible_ids(3).has("scrap_yield")).is_true()
	assert_int(_visible_ids(3).size()).is_equal(5)
	assert_bool(_visible_ids(5).has("crit_chance")).is_true()
	assert_bool(_visible_ids(8).has("crit_mult")).is_true()
	var ten: Array[String] = _visible_ids(10)
	assert_bool(ten.has("optic_range") and ten.has("plating_pct")).is_true()
	assert_int(ten.size()).is_equal(9)
	assert_bool(ten.has("reinvest")).is_false()


func test_best_wave_12_all() -> void:
	assert_int(_visible_ids(12).size()).is_equal(10)


func test_next_unlock() -> void:
	var defs: Array[RunUpgradeDef] = _defs()
	var n: Vector2i = UnlockRules.next_unlock(defs, 4)
	assert_str(defs[n.x].id).is_equal("crit_chance")
	assert_int(n.y).is_equal(5)
	assert_int(UnlockRules.next_unlock(defs, 0).y).is_equal(3)
	assert_that(UnlockRules.next_unlock(defs, 12)).is_equal(Vector2i(-1, 0))
