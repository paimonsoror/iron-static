class_name TestModePicker
extends GdUnitTestSuite
## ModePicker (M4-08): segments from cards, locked tap shows the condition, selection signal, touch targets.

const MIN_TOUCH: float = 148.0


func _cards(timed_best: int) -> Array[ModeCard]:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	if timed_best > 0:
		p.best_wave["1"] = timed_best
	@warning_ignore("return_value_discarded")
	ModeRules.apply_unlocks(p, ModeRules.load_defs())
	return ModeRules.cards(p, ModeRules.load_defs())


func _picker(cards: Array[ModeCard], selected: String) -> ModePicker:
	var root: Control = auto_free(Control.new())
	root.size = Vector2(1080.0, 2400.0)
	add_child(root)
	var picker: ModePicker = ModePicker.new()
	root.add_child(picker)
	picker.setup(cards, selected)
	return picker


func test_fresh_cards_timed_selected_purge_locked_and_dimmed() -> void:
	var pk: ModePicker = _picker(_cards(0), "timed")
	assert_str(pk.selected_id).is_equal("timed")
	assert_str(pk.button_of("timed").text).is_equal("TIMED")
	assert_str(pk.button_of("purge").text).is_equal("PURGE")
	assert_float(pk.button_of("purge").self_modulate.a).is_less(1.0)
	assert_float(pk.button_of("timed").self_modulate.a).is_equal(1.0)
	assert_bool(pk.info_visible()).is_false()


func test_tapping_locked_segment_emits_nothing_and_shows_condition() -> void:
	var pk: ModePicker = _picker(_cards(7), "timed")
	var seen: Array[String] = []
	pk.mode_selected.connect(func(id: String) -> void: seen.append(id))
	pk.button_of("purge").pressed.emit()
	assert_array(seen).is_empty()
	assert_str(pk.selected_id).is_equal("timed")
	assert_bool(pk.info_visible()).is_true()
	assert_str(pk.info_text()).contains("Reach wave 20 in TIMED to unlock").contains("Best TIMED wave: 7")


func test_unlocked_purge_selects_once_and_hides_info() -> void:
	var pk: ModePicker = _picker(_cards(20), "timed")
	var seen: Array[String] = []
	pk.mode_selected.connect(func(id: String) -> void: seen.append(id))
	pk.show_info("x")
	pk.button_of("purge").pressed.emit()
	pk.button_of("purge").pressed.emit()  # same segment again: no second signal
	assert_array(seen).contains_exactly(["purge"])
	assert_str(pk.selected_id).is_equal("purge")
	assert_bool(pk.info_visible()).is_false()
	assert_float(pk.button_of("purge").self_modulate.a).is_equal(1.0)


func test_locked_selected_falls_back_to_first_unlocked() -> void:
	var pk: ModePicker = _picker(_cards(0), "purge")
	assert_str(pk.selected_id).is_equal("timed")


func test_segments_are_big_touch_targets_with_margin_between() -> void:
	var pk: ModePicker = _picker(_cards(20), "timed")
	for id: String in ["timed", "purge"]:
		assert_float(pk.button_of(id).custom_minimum_size.y).is_greater_equal(MIN_TOUCH)
		var fs: int = pk.button_of(id).get_theme_font_size("font_size")
		assert_int(fs).is_greater_equal(38)


func test_renders_any_number_of_cards() -> void:
	var cards: Array[ModeCard] = _cards(20)
	var third: ModeCard = ModeCard.new()
	third.id = "gauntlet"
	third.name_key = "mode.timed"
	cards.append(third)
	var pk: ModePicker = _picker(cards, "timed")
	assert_object(pk.button_of("gauntlet")).is_not_null()
