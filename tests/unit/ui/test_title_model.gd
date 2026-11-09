class_name TestTitleModel
extends GdUnitTestSuite
## M3-28 TitleModel: which buttons show, the quality ladder, the hero frame, layout math and the shimmer caps.


func _fresh() -> PlayerProfile:
	return PlayerProfile.fresh(1000, "dev")


func test_fresh_profile_shows_new_game_and_settings_only() -> void:
	var p: PlayerProfile = _fresh()
	assert_bool(TitleModel.has_progress(p)).is_false()
	assert_array(TitleModel.rows(TitleModel.has_progress(p))).is_equal(["new_game", "settings"])


func test_progress_shows_continue_first() -> void:
	var by_runs: PlayerProfile = _fresh()
	by_runs.runs_total = 1
	var by_foundry: PlayerProfile = _fresh()
	by_foundry.foundry = {"hull_integrity": 1}
	var by_counter: PlayerProfile = _fresh()
	by_counter.run_counter = 1
	for p: PlayerProfile in [by_runs, by_foundry, by_counter]:
		assert_bool(TitleModel.has_progress(p)).is_true()
		assert_array(TitleModel.rows(true)).is_equal(["continue", "new_game", "settings"])
	assert_bool(TitleModel.has_progress(null)).is_false()


func test_label_keys_exist_in_strings() -> void:
	for id: String in ["continue", "new_game", "settings"]:
		assert_bool(Strings.get_text(TitleModel.label_key(id)) != TitleModel.label_key(id)).is_true()


func test_hero_is_selected_unlocked_frame_else_vanguard() -> void:
	var defs: Array[FrameDef] = FrameRules.load_defs()
	var p: PlayerProfile = _fresh()
	assert_str(TitleModel.hero_frame(p, defs)).is_equal("vanguard")
	p.frame_selected = "bulwark"
	assert_str(TitleModel.hero_frame(p, defs)).is_equal("vanguard")  # not unlocked: falls back
	@warning_ignore("return_value_discarded")
	p.unlock_frame("bulwark")
	assert_str(TitleModel.hero_frame(p, defs)).is_equal("bulwark")
	@warning_ignore("return_value_discarded")
	p.unlock_frame("striker")
	p.frame_selected = "striker"
	assert_str(TitleModel.hero_frame(p, defs)).is_equal("striker")


func test_quality_ladder() -> void:
	assert_int(TitleModel.smoke_layers(VisualQuality.Tier.HIGH).size()).is_equal(3)
	assert_int(TitleModel.smoke_layers(VisualQuality.Tier.MID).size()).is_equal(2)
	assert_array(TitleModel.smoke_layers(VisualQuality.Tier.LOW)).is_equal([1])
	assert_bool(TitleModel.embers_enabled(VisualQuality.Tier.HIGH)).is_true()
	assert_bool(TitleModel.embers_enabled(VisualQuality.Tier.MID)).is_true()
	assert_bool(TitleModel.embers_enabled(VisualQuality.Tier.LOW)).is_false()
	assert_bool(TitleModel.flare_enabled(VisualQuality.Tier.HIGH, false)).is_true()
	assert_bool(TitleModel.flare_enabled(VisualQuality.Tier.HIGH, true)).is_false()
	assert_bool(TitleModel.flare_enabled(VisualQuality.Tier.LOW, false)).is_false()
	assert_bool(TitleModel.scanlines_enabled(VisualQuality.Tier.HIGH, false)).is_true()
	assert_bool(TitleModel.scanlines_enabled(VisualQuality.Tier.MID, false)).is_false()


func test_shimmer_uniform_ranges_keep_the_logo_readable() -> void:
	assert_bool(TitleModel.tear_px(TitleModel.TEAR_DX_MAX) <= TitleModel.MAX_TEAR_PX).is_true()
	assert_bool(TitleModel.TEAR_DX_MIN > 0.0 and TitleModel.TEAR_DX_MIN < TitleModel.TEAR_DX_MAX).is_true()
	# channel split in px at the shown scale stays below the tear cap
	var split_px: float = TitleModel.SHIMMER_SPLIT * TitleArt.LOGO_SHEET_W * TitleArt.LOGO_SCALE
	assert_bool(split_px <= TitleModel.MAX_TEAR_PX).is_true()
	assert_bool(TitleModel.SWEEP_STRENGTH <= 0.5).is_true()


func test_buttons_block_is_bottom_anchored_inside_the_column() -> void:
	var col := Rect2(0.0, 110.0, 1080.0, 2160.0)
	for n: int in [2, 3]:
		var r: Rect2 = TitleModel.buttons_rect(col, n)
		assert_bool(col.encloses(r)).is_true()
		assert_float(r.end.y).is_equal(col.end.y - TitleModel.BOTTOM_PAD)
		assert_float(r.get_center().x).is_equal(540.0)
	assert_bool(TitleModel.ROW_H >= 148.0).is_true()


func test_logo_stays_below_the_safe_top() -> void:
	assert_float(TitleModel.logo_center_y(Vector2(1080.0, 2400.0), 0.0)).is_equal(540.0)
	var y: float = TitleModel.logo_center_y(Vector2(1990.0, 1920.0), 200.0)
	assert_bool(y - TitleModel.LOGO_HALF_H >= 200.0).is_true()
