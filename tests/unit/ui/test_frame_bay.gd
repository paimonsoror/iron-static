class_name TestFrameBay
extends GdUnitTestSuite
## FrameBay screen (M3-29): carousel, select, locked deny, confirm/back signals, persistence, run config.

var _fs: MemorySaveFs
var _old_saves: SaveService
var _old_controller: RunController
var _old_problem: SaveService.Problem
var _spy: SpyAudioDirector


func before_test() -> void:
	SaveKey.reset()
	_old_saves = Game.saves
	_old_controller = Game.controller
	_old_problem = Game.save_problem
	_spy = auto_free(SpyAudioDirector.new())
	AudioHooks.override = _spy
	_fs = MemorySaveFs.new()
	Game.controller = RunController.new()
	Game.controller.last_run_path = "user://runs/test_frame_bay.json"
	_use_service(SaveService.new(_fs, FakeClock.new(1000), "dev"))


func after_test() -> void:
	Game.saves = _old_saves
	Game.controller = _old_controller
	Game.save_problem = _old_problem
	AudioHooks.override = null


func _use_service(s: SaveService) -> void:
	@warning_ignore("return_value_discarded")
	s.load_profile()
	s.attach(Game.controller)
	Game.saves = s
	Game.save_problem = s.problem


func _unlock(best_wave: int) -> void:
	var p: PlayerProfile = Game.profile()
	var id: int = p.begin_run()
	@warning_ignore("return_value_discarded")
	FrameRules.bank(p, RunSummary.make(id, best_wave, BigNum.from_int(5)), FrameRules.load_defs())


func _bay(size: Vector2 = Vector2(1080.0, 2400.0)) -> FrameBay:
	var root: Control = auto_free(Control.new())
	root.size = size
	add_child(root)
	var s: FrameBay = (load("res://src/ui/frames/frame_bay.tscn") as PackedScene).instantiate()
	root.add_child(s)
	s.size = size
	s.enter()
	return s


func test_opens_on_selected_frame() -> void:
	_unlock(20)
	assert_bool(FrameRules.select(Game.profile(), "striker")).is_true()
	var s: FrameBay = _bay()
	assert_str(s.shown_card().id).is_equal("striker")
	assert_str(s.action_button().text).is_equal("CONTINUE")


func test_carousel_pages_and_wraps() -> void:
	var s: FrameBay = _bay()
	assert_str(s.shown_card().id).is_equal("vanguard")
	s.next_button().pressed.emit()
	assert_str(s.shown_card().id).is_equal("bulwark")
	s.prev_button().pressed.emit()
	s.prev_button().pressed.emit()
	assert_str(s.shown_card().id).is_equal("striker")
	assert_array(_spy.sfx).contains(["sfx_ui_tap"])


func test_fresh_profile_locked_cards_show_condition() -> void:
	var s: FrameBay = _bay()
	s.page(1)
	var view: FrameCardView = s.card_view()
	assert_bool(view.lock_label().visible).is_true()
	assert_str(view.lock_label().text).is_equal("REACH WAVE 8")
	assert_str(s.action_button().text).is_equal("REACH WAVE 8")
	assert_str(view.value_text("hull")).is_equal("+60%")
	assert_str(view.value_text("rate")).is_equal("-25%")
	s.page(1)
	assert_str(view.lock_label().text).is_equal("REACH WAVE 15")


func test_negative_delta_never_red() -> void:
	var s: FrameBay = _bay()
	s.page(1)
	assert_bool(s.card_view().value_color("rate").is_equal_approx(Palette.TEXT_DIM)).is_true()
	assert_bool(s.card_view().value_color("hull").is_equal_approx(Palette.AMBER)).is_true()


func test_locked_press_denies_and_changes_nothing() -> void:
	var s: FrameBay = _bay()
	s.page(1)
	var emitted: Array[bool] = [false]
	s.confirmed.connect(func() -> void: emitted[0] = true)
	s.action_button().pressed.emit()
	assert_str(Game.profile().frame_selected).is_equal("vanguard")
	assert_bool(emitted[0]).is_false()
	assert_array(_spy.sfx).is_equal(["sfx_ui_deny"])


func test_select_unlocked_persists_and_keeps_vanguard_reference() -> void:
	_unlock(8)
	var s: FrameBay = _bay()
	s.page(1)
	assert_str(s.action_button().text).is_equal("SELECT")
	s.action_button().pressed.emit()
	assert_str(Game.profile().frame_selected).is_equal("bulwark")
	assert_str(s.action_button().text).is_equal("CONTINUE")
	assert_bool(s.card_view().tag_label().visible).is_true()
	assert_str(s.card_view().value_text("hull")).is_equal("+60%")  # still compared to VANGUARD
	assert_bool(Game.saves.save_now()).is_true()
	var reloaded := SaveService.new(_fs, FakeClock.new(2000), "dev")
	@warning_ignore("return_value_discarded")
	reloaded.load_profile()
	assert_str(reloaded.profile.frame_selected).is_equal("bulwark")


func test_confirm_and_back_signals() -> void:
	var s: FrameBay = _bay()
	var hits: Array[int] = [0, 0]
	s.confirmed.connect(func() -> void: hits[0] += 1)
	s.back_pressed.connect(func() -> void: hits[1] += 1)
	s.action_button().pressed.emit()
	s.back_button().pressed.emit()
	assert_int(hits[0]).is_equal(1)
	assert_int(hits[1]).is_equal(1)


func test_selected_frame_reaches_run_config() -> void:
	_unlock(8)
	assert_bool(FrameRules.select(Game.profile(), "bulwark")).is_true()
	var w: SimWorld = Game.saves.start_run()
	assert_str(w.config.frame_id).is_equal("bulwark")
	assert_float(w.stats.hull_integrity).is_equal_approx(160.0, 0.01)


func test_touch_targets_and_portrait_by_state() -> void:
	_unlock(8)
	var s: FrameBay = _bay()
	for b: Button in [s.action_button(), s.prev_button(), s.next_button(), s.back_button()]:
		assert_float(b.custom_minimum_size.y).is_greater_equal(148.0)
	var unlocked_tex: Texture2D = s.card_view().portrait_texture()
	s.page(2)
	assert_object(s.card_view().portrait_texture()).is_not_same(unlocked_tex)
	assert_bool(s.card_view().portrait_texture() is AtlasTexture).is_true()


func test_wide_layout_is_1080_column() -> void:
	var s: FrameBay = _bay(Vector2(1990.0, 1920.0))
	assert_int(s.layout_mode()).is_equal(LayoutMode.Mode.WIDE)
	assert_float(s.content.size.x).is_equal(1080.0)
