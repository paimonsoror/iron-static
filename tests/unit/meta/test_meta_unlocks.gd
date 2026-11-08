class_name TestMetaUnlocks
extends GdUnitTestSuite
## MetaUnlocks (M3-06): Foundry gate, visible nav, next unlock line.


func test_foundry_locked_for_a_fresh_profile() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	assert_bool(MetaUnlocks.foundry_screen_unlocked(p)).is_false()
	assert_array(MetaUnlocks.visible_nav(p)).is_equal([&"home"])


func test_foundry_unlocked_after_one_banked_run() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	var s: RunSummary = RunSummary.new()
	s.run_id = p.begin_run()
	s.death_wave = 4
	s.data_run = BigNum.from_int(10)
	assert_bool(p.bank_run(s)).is_true()
	assert_bool(MetaUnlocks.foundry_screen_unlocked(p)).is_true()
	assert_array(MetaUnlocks.visible_nav(p)).is_equal([&"home", &"foundry"])


func test_next_unlock_line_wraps_unlock_rules() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	var line: Vector2i = MetaUnlocks.next_unlock_line(cfg.upgrades, 0)
	assert_vector(line).is_equal(UnlockRules.next_unlock(cfg.upgrades, 0))
	assert_int(line.y).is_equal(3)
	assert_int(MetaUnlocks.next_unlock_line(cfg.upgrades, 99).x).is_equal(-1)
