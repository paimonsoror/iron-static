class_name TestHomeModel
extends GdUnitTestSuite
## HomeModel (M3-15): texts, next-unlock hint, Foundry visibility and the affordable hint chip.


func _model(runs: int, best: int, data: String) -> HomeModel:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	p.runs_total = runs
	p.data = BigNum.parse(data)
	if best > 0:
		p.best_wave["1"] = best
	var upgrades: Array[RunUpgradeDef] = SimConfigLoader.load_default(1).upgrades
	var foundry := FoundryService.new(SimConfigLoader.load_foundry_defs(), upgrades)
	return HomeModel.build(p, upgrades, foundry, FrameRules.load_defs())


func test_best_zero_uses_the_none_text() -> void:
	var m: HomeModel = _model(0, 0, "0")
	assert_str(m.best_text).is_equal(Strings.get_text("home.best_none"))
	assert_bool(m.best_known).is_false()


func test_best_14_text_and_texts_have_no_missing_keys() -> void:
	var before: int = Strings.missing_count
	var m: HomeModel = _model(3, 14, "400")
	assert_str(m.best_text).is_equal("BEST  W14")
	assert_str(m.sector_text).is_equal("SECTOR 1")
	assert_str(m.data_text).is_equal("DATA 400")
	assert_str(m.frame_text).is_equal("FRAME VANGUARD")
	assert_str(m.pr_text).starts_with("PR ")
	assert_int(Strings.missing_count).is_equal(before)


func test_next_unlock_at_best_4_names_crit_chance_and_wave_5() -> void:
	var m: HomeModel = _model(1, 4, "0")
	assert_str(m.next_unlock_id).is_equal("crit_chance")
	assert_int(m.next_unlock_wave).is_equal(5)
	assert_str(m.hint_text).contains("CRIT CHANCE").contains("5")
	assert_bool(m.all_unlocked).is_false()


func test_all_unlocked_at_best_12() -> void:
	var m: HomeModel = _model(1, 12, "0")
	assert_bool(m.all_unlocked).is_true()
	assert_str(m.hint_text).is_equal(Strings.get_text("home.all_unlocked"))


func test_foundry_nav_hidden_for_a_fresh_profile_and_shown_after_one_run() -> void:
	var fresh: HomeModel = _model(0, 0, "0")
	assert_bool(fresh.foundry_visible).is_false()
	assert_bool(fresh.nav_visible()).is_false()
	assert_array(fresh.nav).contains_exactly([MetaUnlocks.NAV_HOME])
	var after: HomeModel = _model(1, 3, "0")
	assert_bool(after.foundry_visible).is_true()
	assert_bool(after.nav_visible()).is_true()
	assert_array(after.nav).contains_exactly([MetaUnlocks.NAV_HOME, MetaUnlocks.NAV_FOUNDRY])


func test_hint_chip_only_when_something_is_affordable() -> void:
	var broke: HomeModel = _model(1, 3, "0")
	assert_int(broke.affordable).is_equal(0)
	assert_bool(broke.hint_chip_visible()).is_false()
	var rich: HomeModel = _model(3, 14, "400")
	assert_int(rich.affordable).is_greater(0)
	assert_bool(rich.hint_chip_visible()).is_true()
	assert_str(rich.foundry_hint_text).contains(str(rich.affordable))
