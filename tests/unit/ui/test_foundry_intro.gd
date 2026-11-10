class_name TestFoundryIntro
extends GdUnitTestSuite
## Foundry explainer dialog (FO-1): shows on entry until closed with the box ticked, the "?" button reopens it, back
## closes it, the flag survives a save round trip, the FTUE pointer waits for it, every text key exists.

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


func _profile(runs: int = 1) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.fresh(0, "test")
	p.data = BigNum.from_int(500)
	p.runs_total = runs
	return p


func _screen(p: PlayerProfile, size: Vector2 = Vector2(1080.0, 2400.0)) -> FoundryScreen:
	var root: Control = auto_free(Control.new())
	root.size = size
	add_child(root)
	var s: FoundryScreen = (load("res://src/ui/foundry/foundry_screen.tscn") as PackedScene).instantiate()
	s.use_profile(p)
	s.use_save_hooks(_count_request, _count_now)
	root.add_child(s)
	s.size = size
	s.apply_safe_margins(Vector4.ZERO)
	s.enter()
	return s


func test_fresh_profile_shows_the_dialog_on_first_entry() -> void:
	var s: FoundryScreen = _screen(_profile())
	assert_bool(s.intro_open()).is_true()
	assert_bool(s.intro.ticked()).is_false()
	assert_str(s.intro.title_text()).is_equal("THE FOUNDRY")


func test_closing_unticked_shows_it_again_next_entry() -> void:
	var p: PlayerProfile = _profile()
	var s: FoundryScreen = _screen(p)
	s.intro.ok_button().pressed.emit()
	assert_bool(s.intro_open()).is_false()
	assert_bool(FoundryIntroFlag.is_hidden(p)).is_false()
	assert_int(_saves_now).is_equal(0)
	s.leave()
	s.enter()
	assert_bool(s.intro_open()).is_true()


func test_ticked_hides_it_and_the_flag_survives_a_save_round_trip() -> void:
	var p: PlayerProfile = _profile()
	var s: FoundryScreen = _screen(p)
	s.intro.toggle_button().button_pressed = true
	s.intro.ok_button().pressed.emit()
	assert_bool(FoundryIntroFlag.is_hidden(p)).is_true()
	assert_int(_saves_requested).is_equal(1)
	assert_int(_saves_now).is_equal(1)
	s.leave()
	s.enter()
	assert_bool(s.intro_open()).is_false()
	var loaded: PlayerProfile = PlayerProfile.from_dict(p.to_dict())
	assert_bool(FoundryIntroFlag.is_hidden(loaded)).is_true()
	var s2: FoundryScreen = _screen(loaded)
	assert_bool(s2.intro_open()).is_false()


func test_help_button_reopens_it_with_the_box_reflecting_the_flag() -> void:
	var p: PlayerProfile = _profile()
	assert_bool(FoundryIntroFlag.set_hidden(p, true)).is_true()
	var s: FoundryScreen = _screen(p)
	assert_bool(s.intro_open()).is_false()
	s.help_button.pressed.emit()
	assert_bool(s.intro_open()).is_true()
	assert_bool(s.intro.ticked()).is_true()
	s.intro.toggle_button().button_pressed = false  # untick: it shows again next time
	s.intro.ok_button().pressed.emit()
	assert_bool(FoundryIntroFlag.is_hidden(p)).is_false()
	assert_bool(p.extra.has(FoundryIntroFlag.KEY)).is_false()


func test_back_closes_the_dialog_first_then_the_screen_may_leave() -> void:
	var s: FoundryScreen = _screen(_profile())
	assert_bool(s.on_back()).is_true()
	assert_bool(s.intro_open()).is_false()
	assert_bool(s.on_back()).is_false()


func test_dialog_blocks_touches_to_the_rows_and_is_independent_of_ftue_skip() -> void:
	var p: PlayerProfile = _profile()
	var ftue: FtueState = FtueState.load_from(FtueScript.load_default(), p)
	ftue.skip_all()
	ftue.store_to(p)
	var s: FoundryScreen = _screen(p)
	assert_bool(s.intro_open()).is_true()
	assert_int(s.intro.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


func test_locked_foundry_shows_no_dialog_and_no_help_button() -> void:
	var s: FoundryScreen = _screen(_profile(0))
	assert_bool(s.is_locked()).is_true()
	assert_bool(s.intro_open()).is_false()
	assert_bool(s.help_button.visible).is_false()


func test_ftue_pointer_waits_for_the_dialog() -> void:
	var s: FoundryScreen = _screen(_profile())
	var root: Control = s.get_parent()
	var overlay := FtueOverlay.new()
	overlay.reduce_motion = true
	root.add_child(overlay)
	overlay.blocker = s.intro_open
	overlay.target_resolver = func(_t: String) -> Rect2: return Rect2(100.0, 500.0, 300.0, 200.0)
	overlay.start_run(SimWorld.new(SimConfigLoader.load_default(1)), PlayerProfile.fresh(0, "ftue"))
	while overlay.state.active() != null:  # the run-1 beats are over by the time the player reaches the Foundry
		@warning_ignore("return_value_discarded")
		overlay.state.complete(overlay.state.active().id)
	overlay.set_screen(AppFlow.Screen.FOUNDRY)
	overlay.on_foundry_opened()
	assert_str(overlay.state.active().id).is_equal("foundry_hold")
	assert_bool(s.intro_open()).is_true()
	assert_bool(overlay.is_hint_visible()).is_false()
	s.intro.ok_button().pressed.emit()
	overlay.set_screen(AppFlow.Screen.FOUNDRY)
	assert_bool(overlay.is_hint_visible()).is_true()


func test_touch_targets_and_layout_inside_the_safe_area() -> void:
	var s: FoundryScreen = _screen(_profile(), Vector2(1990.0, 1920.0))
	assert_float(s.intro.ok_button().custom_minimum_size.y).is_greater_equal(148.0)
	assert_float(s.intro.toggle_button().custom_minimum_size.y).is_greater_equal(148.0)
	assert_float(s.help_button.custom_minimum_size.x).is_greater_equal(148.0)
	assert_float(s.help_button.custom_minimum_size.y).is_greater_equal(148.0)


func test_every_text_key_exists() -> void:
	var before: int = Strings.missing_count
	for key: String in (
		["foundry.help", "foundry.intro.title", "foundry.intro.hide", "foundry.intro.ok"]
		+ Array(FoundryIntro.BODY_KEYS)
	):
		assert_str(Strings.get_text(key)).is_not_equal(key)
	assert_int(Strings.missing_count).is_equal(before)


func test_copy_stays_short_and_names_no_banned_word() -> void:
	var intro: FoundryIntro = auto_free(FoundryIntro.new())
	var words: int = intro.body_text().split(" ", false).size()
	assert_int(words).is_less_equal(60)
	var text: String = intro.body_text().to_lower()
	for banned: String in ["cash", "coins", "gems", "workshop", "terminator"]:
		assert_bool(text.contains(banned)).is_false()
