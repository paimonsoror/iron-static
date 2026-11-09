class_name TestResultsKills
extends GdUnitTestSuite
## Kill entries, kill strip and the image-first fields of ResultsModel (M4).

const IDS: PackedStringArray = ["skitter", "dart", "walker", "lancer", "boss_hulk"]


func _kills(values: Array[int]) -> PackedInt32Array:
	var p := PackedInt32Array()
	for v: int in values:
		@warning_ignore("return_value_discarded")
		p.append(v)
	return p


func test_entries_sorted_by_count_skip_zero_and_flag_boss() -> void:
	var list: Array[KillEntry] = KillEntry.list(_kills([5, 0, 40, 40, 1]), IDS)
	assert_int(list.size()).is_equal(4)
	assert_str(list[0].id).is_equal("walker")
	assert_str(list[1].id).is_equal("lancer")
	assert_str(list[2].id).is_equal("skitter")
	assert_int(list[2].count).is_equal(5)
	assert_str(list[3].id).is_equal("boss_hulk")
	assert_bool(list[3].boss).is_true()
	assert_bool(list[0].boss).is_false()


func test_empty_kills_give_no_entries() -> void:
	assert_int(KillEntry.list(_kills([0, 0, 0]), IDS).size()).is_equal(0)


func test_display_name_falls_back_to_upper_id() -> void:
	assert_str(KillEntry.display_name("boss_hulk")).is_equal("HULK")
	assert_str(KillEntry.display_name("zzz")).is_equal("ZZZ")


func test_strip_builds_one_chip_per_entry_with_counts() -> void:
	var strip: ResultsKillStrip = auto_free(ResultsKillStrip.new())
	add_child(strip)
	strip.show_entries(KillEntry.list(_kills([412, 96, 0, 0, 1]), IDS))
	assert_int(strip.chips().size()).is_equal(3)
	assert_bool(strip.visible).is_true()
	var first: Label = strip.chips()[0].get_child(0).get_child(1)
	assert_str(first.text).is_equal("x%s" % NumberFormat.format(BigNum.from_int(412)))
	strip.show_entries([])
	assert_bool(strip.visible).is_false()


func test_model_image_first_fields() -> void:
	var run := RunStats.new()
	run.death_wave = 31
	run.kills = 9
	run.kills_by_type[0] = 9
	var info := BankedInfo.new()
	info.has_bank = true
	info.mode = "purge"
	info.previous_best = 29
	info.new_best = 31
	info.data_total = BigNum.from_int(381)
	info.unlocked_frames = ["bulwark"]
	var m: ResultsModel = ResultsModel.from_run(run, EconomyState.new(), 189 * 30, "SKITTER", info, IDS, "skitter")
	assert_str(m.wave_big_text).is_equal("WAVE 31")
	assert_str(m.mode_chip_text).is_equal("PURGE")
	assert_str(m.best_short_text).is_equal("BEST 31")
	assert_str(m.time_value_text).is_equal("3m 09s")
	assert_str(m.data_total_text).is_equal("TOTAL 381")
	assert_str(m.data_gain("84")).is_equal("+84")
	assert_str(m.killer_name_text).is_equal("SKITTER")
	assert_str(m.chip_frame_id).is_equal("bulwark")
	assert_int(m.kill_entries.size()).is_equal(1)
	var none: ResultsModel = ResultsModel.from_run(run, EconomyState.new(), 0, "")
	assert_str(none.killer_name_text).is_equal("UNKNOWN")
	assert_str(none.mode_chip_text).is_equal("")


func test_every_enemy_in_the_table_has_art_and_a_name_string() -> void:
	for def: EnemyDef in SimConfigLoader.load_default(1).enemies:
		assert_bool(ArtSlots.has(def.id)).is_true()
		assert_bool(Strings.has_key("enemy.name." + def.id)).is_true()
