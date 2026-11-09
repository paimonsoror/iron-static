class_name TestResultsOverlay
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/results_overlay.tscn"
const MIN_TOUCH: float = 148.0
const MIN_TEXT: int = 38


func _overlay(height: float = 2400.0, reduced: bool = true) -> ResultsOverlay:
	var root: Control = auto_free(Control.new())
	root.size = Vector2(1080.0, height)
	add_child(root)
	var packed: PackedScene = load(SCENE_PATH)
	var overlay: ResultsOverlay = packed.instantiate()
	overlay.reduce_motion = reduced
	root.add_child(overlay)
	return overlay


func _dead_run() -> RunController:
	var c := RunController.new()
	c.start_run(1)
	c.fast_forward(60000)
	return c


func test_hidden_by_default_and_shows_fields_after_run() -> void:
	var overlay: ResultsOverlay = _overlay()
	assert_bool(overlay.visible).is_false()
	var c: RunController = _dead_run()
	overlay.show_results(c.world)
	assert_bool(overlay.visible).is_true()
	var wave_label: Label = overlay.get_node("%WaveLabel")
	var cause_label: Label = overlay.get_node("%CauseLabel")
	assert_str(wave_label.text).is_equal("WAVE REACHED  %d" % c.world.run.death_wave)
	assert_str(cause_label.text).starts_with("CAUSE  ")
	assert_bool(overlay.is_settled()).is_true()


func test_animated_run_ends_on_exact_model_texts() -> void:
	var overlay: ResultsOverlay = _overlay(2400.0, false)
	var c: RunController = _dead_run()
	overlay.show_results(c.world, BankedInfo.new())
	assert_bool(overlay.is_settled()).is_false()
	assert_str((overlay.get_node("%WaveLabel") as Label).text).is_equal("WAVE REACHED  0")
	overlay.advance(ResultsAnim.total_s(ResultsOverlay.ROW_COUNT, false) + 0.01)
	var m: ResultsModel = ResultsModel.from_run(
		c.world.run, c.world.economy, c.world.tick, RunController.cause_text(c.world)
	)
	assert_bool(overlay.is_settled()).is_true()
	assert_str((overlay.get_node("%KillsLabel") as Label).text).is_equal(m.kills_text)
	assert_str((overlay.get_node("%DataLabel") as Label).text).is_equal(m.data_text)
	assert_str((overlay.get_node("%ScrapLabel") as Label).text).is_equal(m.scrap_text)


func test_redeploy_button_emits_signal_immediately() -> void:
	var overlay: ResultsOverlay = _overlay(2400.0, false)
	var hits: Array[int] = []
	overlay.redeploy_pressed.connect(func() -> void: hits.append(1))
	overlay.show_results(_dead_run().world)
	var button: Button = overlay.get_node("%RedeployButton")
	assert_bool(button.disabled).is_false()
	button.pressed.emit()
	assert_int(hits.size()).is_equal(1)


func _check_layout(height: float) -> void:
	var overlay: ResultsOverlay = _overlay(height)
	var w: SimWorld = _dead_run().world
	var info: BankedInfo = _info(w.run.death_wave, 0)
	info.unlocked_frames = ["bulwark"]
	info.save_failed = true
	overlay.show_results(w, info)
	await await_idle_frame()
	await await_idle_frame()
	var card: Control = overlay.get_node("%Card")
	var screen := Rect2(0.0, 0.0, 1080.0, height)
	var card_rect := Rect2(card.global_position, card.size)
	assert_bool(screen.encloses(card_rect)).is_true()
	var button: Button = overlay.get_node("%RedeployButton")
	assert_float(button.size.y).is_greater_equal(MIN_TOUCH)
	for bn: String in ["%FoundryButton", "%HomeButton"]:
		var sb: Button = overlay.get_node(bn)
		assert_float(sb.size.y).is_greater_equal(MIN_TOUCH)
		assert_bool(card_rect.encloses(Rect2(sb.global_position, sb.size))).is_true()
		assert_int(sb.get_theme_font_size("font_size")).is_greater_equal(MIN_TEXT)
	assert_bool(card_rect.encloses(Rect2(button.global_position, button.size))).is_true()
	var rects: Array[Rect2] = []
	for n: String in [
		"%TitleLabel", "%ChipPanel", "%Stats", "%SaveWarnLabel", "%RedeployButton", "%FoundryButton", "%HomeButton"
	]:
		var c: Control = overlay.get_node(n)
		rects.append(Rect2(c.global_position, c.size))
	var rows: Array[Rect2] = []
	for n: String in ResultsOverlay.ROW_NAMES:
		var r: Control = overlay.get_node("%" + n)
		rows.append(Rect2(r.global_position, r.size))
	for i: int in rects.size():
		for j: int in range(i + 1, rects.size()):
			assert_bool(rects[i].intersects(rects[j])).is_false()
	for i: int in rows.size():
		assert_bool(rects[2].encloses(rows[i])).is_true()
		for j: int in range(i + 1, rows.size()):
			assert_bool(rows[i].intersects(rows[j])).is_false()
	for n: String in ["%TitleLabel", "%WaveLabel", "%TimeLabel", "%KillsLabel", "%CauseLabel", "%DataLabel"]:
		var label: Label = overlay.get_node(n)
		assert_int(label.get_theme_font_size("font_size")).is_greater_equal(MIN_TEXT)
		var lr := Rect2(label.global_position, label.size)
		assert_bool(lr.size.x > 0.0 and card_rect.encloses(lr)).is_true()
	assert_int((overlay.get_node("%BestLabel") as Label).get_theme_font_size("font_size")).is_greater_equal(MIN_TEXT)
	assert_int(button.get_theme_font_size("font_size")).is_greater_equal(MIN_TEXT)


func test_layout_at_1080x1920() -> void:
	await _check_layout(1920.0)


func test_layout_at_1080x2400() -> void:
	await _check_layout(2400.0)


func test_text_contrast_on_plate_is_at_least_4_5() -> void:
	for c: Color in [
		Palette.AMBER,
		Palette.AMBER_GLOW,
		Palette.TEXT,
		Palette.TEXT_DIM,
		Palette.DATA,
		Palette.SCRAP,
		Palette.ACCENT_SKITTER,
		Palette.ACCENT_DART,
		Palette.ACCENT_WALKER,
		Palette.ACCENT_LANCER,
		Palette.ACCENT_BOSS,
	]:
		assert_float(ThemeBuilder.contrast_ratio(c, Palette.PANEL)).is_greater_equal(4.5)


func _info(wave: int, prev: int) -> BankedInfo:
	var info := BankedInfo.new()
	info.has_bank = true
	info.previous_best = prev
	info.new_best = maxi(prev, wave)
	info.data_total = BigNum.from_int(999)
	info.foundry_unlocked = true
	info.affordable_count = 2
	return info


func test_three_buttons_emit_their_own_signal_once() -> void:
	var overlay: ResultsOverlay = _overlay(2400.0, false)
	var counts: Dictionary[String, int] = {"redeploy": 0, "foundry": 0, "home": 0}
	overlay.redeploy_pressed.connect(func() -> void: counts["redeploy"] += 1)
	overlay.foundry_pressed.connect(func() -> void: counts["foundry"] += 1)
	overlay.home_pressed.connect(func() -> void: counts["home"] += 1)
	var c: RunController = _dead_run()
	overlay.show_results(c.world, _info(c.world.run.death_wave, 0))
	for n: String in ["%RedeployButton", "%FoundryButton", "%HomeButton"]:
		var b: Button = overlay.get_node(n)
		assert_bool(b.visible and not b.disabled).is_true()
		b.pressed.emit()
	assert_int(counts["redeploy"]).is_equal(1)
	assert_int(counts["foundry"]).is_equal(1)
	assert_int(counts["home"]).is_equal(1)
	assert_float(ResultsAnim.BUTTONS_ENABLED_S).is_equal(0.0)


func test_data_count_up_ends_on_exact_banked_text_and_badge_shows() -> void:
	var overlay: ResultsOverlay = _overlay(2400.0, false)
	var c: RunController = _dead_run()
	overlay.show_results(c.world, _info(c.world.run.death_wave, 0))
	assert_bool((overlay.get_node("%BadgeLabel") as Label).visible).is_true()
	overlay.advance(ResultsAnim.total_s(ResultsOverlay.ROW_COUNT, false) + 0.01)
	assert_str((overlay.get_node("%DataLabel") as Label).text).is_equal(overlay.model().data_text)
	assert_str((overlay.get_node("%DataLabel") as Label).text).contains("TOTAL 999")
	assert_str((overlay.get_node("%FoundryButton") as Button).text).is_equal("FOUNDRY  2 AFFORDABLE")


func test_reduce_motion_shows_finals_at_frame_zero_with_chip_and_warning() -> void:
	var overlay: ResultsOverlay = _overlay(2400.0, true)
	var c: RunController = _dead_run()
	var info: BankedInfo = _info(c.world.run.death_wave, 0)
	info.unlocked_frames = ["bulwark"]
	info.save_failed = true
	overlay.show_results(c.world, info)
	assert_bool(overlay.is_settled()).is_true()
	assert_str((overlay.get_node("%DataLabel") as Label).text).is_equal(overlay.model().data_text)
	assert_bool((overlay.get_node("%ChipPanel") as Control).visible).is_true()
	assert_bool((overlay.get_node("%SaveWarnLabel") as Control).visible).is_true()


func test_foundry_button_hidden_for_debug_runs() -> void:
	var overlay: ResultsOverlay = _overlay(2400.0, true)
	overlay.show_results(_dead_run().world, BankedInfo.new())
	assert_bool((overlay.get_node("%FoundryButton") as Control).visible).is_false()
	assert_bool((overlay.get_node("%HomeButton") as Control).visible).is_true()
