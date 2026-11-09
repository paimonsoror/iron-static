class_name TestFoundryScreen
extends GdUnitTestSuite
## FoundryScreen (M3-16): rows, Recommended glow, buying, persistence, DEPLOY, layout and touch targets. The screen
## runs on an injected profile and spy save hooks; nothing touches `Game.saves`.

var _saves_requested: int = 0
var _saves_now: int = 0


func before_test() -> void:
	_saves_requested = 0
	_saves_now = 0
	Game.visual.reduce_motion = true


func after_test() -> void:
	Game.visual.reduce_motion = false


func _count_request() -> void:
	_saves_requested += 1


func _count_now() -> bool:
	_saves_now += 1
	return true


func _profile(data: int, runs: int = 1) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.fresh(0, "test")
	p.data = BigNum.from_int(data)
	p.runs_total = runs
	return p


func _screen(p: PlayerProfile, size: Vector2 = Vector2(1080.0, 2400.0), safe: Vector4 = Vector4.ZERO) -> FoundryScreen:
	var root: Control = auto_free(Control.new())
	root.size = size
	add_child(root)
	var s: FoundryScreen = (load("res://src/ui/foundry/foundry_screen.tscn") as PackedScene).instantiate()
	s.use_profile(p)
	s.use_save_hooks(_count_request, _count_now)
	root.add_child(s)
	s.size = size
	s.apply_safe_margins(safe)
	s.enter()
	return s


func test_four_rows_in_order_and_balance_header() -> void:
	var s: FoundryScreen = _screen(_profile(1234))
	assert_int(s.row_count()).is_equal(4)
	assert_str(s.data_label.text).is_equal("DATA 1.23K")
	assert_str(s.row_at(0).cost_text()).is_equal("20")
	assert_str(s.row_at(1).cost_text()).is_equal("50")
	assert_bool(s.is_locked()).is_false()


func test_no_glow_and_no_preview_when_nothing_is_affordable() -> void:
	var s: FoundryScreen = _screen(_profile(0))
	assert_int(s.recommended_index()).is_equal(-1)
	assert_bool(s.preview_label.visible).is_false()
	for i: int in 4:
		assert_bool(s.row_at(i).has_glow()).is_false()


func test_recommended_moves_after_a_buy() -> void:
	var s: FoundryScreen = _screen(_profile(60))
	assert_int(s.recommended_index()).is_equal(0)  # laser 20 is the cheapest affordable row
	assert_bool(s.row_at(0).has_glow()).is_true()
	assert_bool(s.preview_label.visible).is_true()
	assert_str(s.preview_label.text).contains("NEXT RUN  PR")
	s.row_at(0).buy_pressed.emit(0, 1)  # laser now costs 22, hull 20 is cheaper
	assert_int(s.recommended_index()).is_equal(2)
	assert_bool(s.row_at(0).has_glow()).is_false()
	assert_bool(s.row_at(2).has_glow()).is_true()


func test_recommended_prefers_a_row_near_its_milestone() -> void:
	var p: PlayerProfile = _profile(100000)
	p.set_foundry_level("hull_integrity", 8)
	var s: FoundryScreen = _screen(p)
	assert_int(s.recommended_index()).is_equal(2)


func test_buying_updates_profile_requests_save_and_release_saves() -> void:
	var p: PlayerProfile = _profile(100)
	var s: FoundryScreen = _screen(p)
	s.row_at(0).buy_pressed.emit(0, 1)
	assert_int(p.foundry_level("laser_output")).is_equal(1)
	assert_str(NumberFormat.format(p.data)).is_equal("80")
	assert_int(_saves_requested).is_equal(1)
	assert_int(_saves_now).is_equal(0)
	s.row_at(0).released.emit()
	assert_int(_saves_now).is_equal(1)
	assert_str(s.row_at(0).value_text()).contains("x1.06 -> x1.12")
	assert_str(s.data_label.text).is_equal("DATA 80")
	s.leave()
	assert_int(_saves_now).is_equal(2)


func test_saved_file_reloads_with_the_same_levels() -> void:
	SaveKey.reset()
	var fs := MemorySaveFs.new()
	var svc := SaveService.new(fs, FakeClock.new(1000), "dev")
	@warning_ignore("return_value_discarded")
	svc.load_profile()
	svc.profile.data = BigNum.from_int(500)
	svc.profile.runs_total = 1
	var s: FoundryScreen = _screen(svc.profile)
	s.use_save_hooks(svc.request_save, svc.save_now)
	s.row_at(0).buy_pressed.emit(0, 10)
	s.row_at(1).buy_pressed.emit(1, 1)
	s.leave()
	var again := SaveService.new(fs, FakeClock.new(2000), "dev")
	@warning_ignore("return_value_discarded")
	again.load_profile()
	assert_int(again.profile.foundry_level("laser_output")).is_equal(svc.profile.foundry_level("laser_output"))
	assert_int(again.profile.foundry_level("laser_output")).is_greater(0)
	assert_int(again.profile.foundry_level("cycle_rate")).is_equal(1)
	assert_float(again.profile.data.to_float()).is_equal_approx(svc.profile.data.to_float(), 1e-6)


func test_deploy_emits_and_the_run_starts_with_the_profile_levels() -> void:
	SaveKey.reset()
	var fs := MemorySaveFs.new()
	var svc := SaveService.new(fs, FakeClock.new(1000), "dev")
	@warning_ignore("return_value_discarded")
	svc.load_profile()
	var controller := RunController.new()
	controller.last_run_path = "user://runs/test_foundry_screen.json"
	svc.attach(controller)
	svc.profile.data = BigNum.from_int(300)
	svc.profile.runs_total = 1
	var s: FoundryScreen = _screen(svc.profile)
	s.row_at(0).buy_pressed.emit(0, 10)
	var deployed: Array[bool] = [false]
	s.deploy_pressed.connect(func() -> void: deployed[0] = true)
	s.deploy_button.pressed.emit()
	assert_bool(deployed[0]).is_true()
	var world: SimWorld = svc.start_run()
	var level: int = svc.profile.foundry_level("laser_output")
	assert_int(level).is_greater(0)
	var defs: Array[FoundryDef] = SimConfigLoader.load_foundry_defs()
	var run_def: RunUpgradeDef = FoundryRules.find_run_def(world.config.upgrades, "laser_output")
	var expected: float = FoundryRules.start_value(FoundryRules.find_def(defs, "laser_output"), run_def, level)
	assert_float(world.stats.laser_output).is_equal_approx(expected, 1e-4)
	var idx: int = world.config.upgrades.find(run_def)
	assert_int(world.config.foundry_levels[idx]).is_equal(level)


func test_locked_profile_shows_the_locked_line_and_no_list() -> void:
	var s: FoundryScreen = _screen(_profile(0, 0))
	assert_bool(s.is_locked()).is_true()
	assert_bool(s.locked_label.visible).is_true()
	assert_bool(s.scroll.visible).is_false()
	assert_str(s.locked_label.text).is_equal("COMPLETE A DEPLOYMENT TO UNLOCK")


func test_back_and_deploy_emit_and_play_tap() -> void:
	var spy: SpyAudioDirector = auto_free(SpyAudioDirector.new())
	AudioHooks.override = spy
	var s: FoundryScreen = _screen(_profile(0))
	var backs: Array[int] = [0]
	s.back_pressed.connect(func() -> void: backs[0] += 1)
	s.back_button.pressed.emit()
	s.deploy_button.pressed.emit()
	AudioHooks.override = null
	assert_int(backs[0]).is_equal(1)
	assert_int(spy.count("sfx_ui_tap")).is_equal(2)


func _check_touch_targets(s: FoundryScreen) -> void:
	for b: Button in [s.back_button, s.deploy_button]:
		assert_float(b.get_global_rect().size.y).is_greater_equal(148.0)
	for i: int in s.row_count():
		assert_float(s.row_at(i).buy_button().get_global_rect().size.y).is_greater_equal(148.0)


func test_phone_layout_everything_inside_the_view_and_targets_148() -> void:
	var s: FoundryScreen = _screen(_profile(60))
	await await_millis(60)
	var view := Rect2(0.0, 0.0, 1080.0, 2400.0)
	assert_bool(view.encloses(s.deploy_button.get_global_rect())).is_true()
	assert_bool(view.encloses(s.row_at(3).get_global_rect())).is_true()
	_check_touch_targets(s)


func test_cover_inset_keeps_deploy_in_the_safe_area() -> void:
	var s: FoundryScreen = _screen(_profile(60), Vector2(1080.0, 2341.0), Vector4(0.0, 130.0, 0.0, 48.0))
	await await_millis(60)
	assert_float(s.heading.get_global_rect().position.y).is_greater_equal(130.0)
	assert_float(s.deploy_button.get_global_rect().end.y).is_less_equal(2341.0 - 48.0 + 0.5)
	_check_touch_targets(s)


func test_wide_layout_is_a_1080_column() -> void:
	var s: FoundryScreen = _screen(_profile(60), Vector2(1990.0, 1920.0))
	await await_millis(60)
	assert_int(s.layout_mode()).is_equal(LayoutMode.Mode.WIDE)
	var col := Rect2(455.0, 0.0, 1080.0, 1920.0)
	assert_bool(col.encloses(s.deploy_button.get_global_rect())).is_true()
	assert_bool(col.encloses(s.row_at(0).get_global_rect())).is_true()
	_check_touch_targets(s)
