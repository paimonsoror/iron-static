class_name TestSettingsScreen
extends GdUnitTestSuite
## SettingsScreen (M3-18): every control applies live to the runtime object, writes the profile settings and
## survives a save -> reload; session overrides; slider drag rule; touch sizes. `Game` is the autoload: the test
## swaps in an in-memory SaveService and restores every global it touches.

var _fs: MemorySaveFs
var _old_saves: SaveService
var _old_settings: PlayerSettings
var _old_fps: int


func before_test() -> void:
	SaveKey.reset()
	_old_saves = Game.saves
	_old_settings = Game.settings_applier.capture(Game.visual, Game.audio.settings)
	_old_fps = Engine.max_fps
	_fs = MemorySaveFs.new()
	_use_service(SaveService.new(_fs, FakeClock.new(1000), "dev"))
	Game.settings_applier.apply(PlayerSettings.new(), Game.visual, Game.audio.settings, PackedStringArray())


func after_test() -> void:
	Game.settings_applier.apply(_old_settings, Game.visual, Game.audio.settings, PackedStringArray())
	Game.saves = _old_saves
	Engine.max_fps = _old_fps


func _use_service(s: SaveService) -> void:
	@warning_ignore("return_value_discarded")
	s.load_profile()
	Game.saves = s


func _screen(size: Vector2 = Vector2(1080.0, 2400.0)) -> SettingsScreen:
	var root: Control = auto_free(Control.new())
	root.size = size
	add_child(root)
	var s: SettingsScreen = (load("res://src/ui/settings/settings_screen.tscn") as PackedScene).instantiate()
	root.add_child(s)
	s.size = size
	s.apply_safe_margins(Vector4.ZERO)
	return s


func _stored() -> PlayerSettings:
	return PlayerSettings.from_dict(Game.profile().settings)


func _drag(sl: SettingsSlider, from: Vector2, to: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from
	sl._gui_input(down)
	var move := InputEventMouseMotion.new()
	move.position = to
	sl._gui_input(move)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to
	sl._gui_input(up)


func _choose(s: SettingsScreen, setting: String, index: int) -> void:
	var c: SettingsChoice = s.choices[setting]
	c.buttons[index].pressed.emit()


func _toggle(s: SettingsScreen, setting: String, on: bool) -> void:
	var t: SettingsToggle = s.toggles[setting]
	t.button_pressed = on


func test_sound_and_music_sliders_apply_and_persist() -> void:
	var s: SettingsScreen = _screen()
	var sfx: SettingsSlider = s.sliders["sfx"]
	sfx.size = Vector2(1000.0, 148.0)
	_drag(sfx, Vector2(900.0, 70.0), Vector2(512.0, 72.0))
	assert_float(Game.audio.settings.sfx_volume).is_equal_approx(0.5, 0.06)
	assert_float(_stored().sfx).is_equal_approx(Game.audio.settings.sfx_volume, 0.0001)
	var music: SettingsSlider = s.sliders["music"]
	music.size = Vector2(1000.0, 148.0)
	_drag(music, Vector2(500.0, 70.0), Vector2(112.0, 72.0))
	assert_float(Game.audio.settings.music_volume).is_less(0.2)
	assert_float(_stored().music).is_equal_approx(Game.audio.settings.music_volume, 0.0001)
	assert_bool(Game.saves.scheduler.is_pending()).is_true()


func test_slider_vertical_drag_changes_nothing() -> void:
	var s: SettingsScreen = _screen()
	var sfx: SettingsSlider = s.sliders["sfx"]
	sfx.size = Vector2(1000.0, 148.0)
	var before: float = Game.audio.settings.sfx_volume
	_drag(sfx, Vector2(500.0, 70.0), Vector2(520.0, 670.0))
	assert_float(Game.audio.settings.sfx_volume).is_equal(before)
	assert_bool(sfx.is_dragging()).is_false()
	assert_bool(Game.saves.scheduler.is_pending()).is_false()


func test_mute_and_reduce_motion_toggles() -> void:
	var s: SettingsScreen = _screen()
	_toggle(s, "muted", true)
	assert_bool(Game.audio.settings.muted).is_true()
	assert_bool(_stored().muted).is_true()
	_toggle(s, "reduce_motion", true)
	assert_bool(Game.visual.reduce_motion).is_true()
	assert_bool(_stored().reduce_motion).is_true()
	assert_float(Game.visual.effective_shake_px()).is_equal(0.0)


func test_choices_apply_to_runtime_and_profile() -> void:
	var s: SettingsScreen = _screen()
	_choose(s, "shake", 2)
	assert_int(Game.visual.screen_shake).is_equal(VisualSettings.Shake.NORMAL)
	assert_str(_stored().shake).is_equal("normal")
	_choose(s, "scanlines", 0)
	assert_float(Game.visual.scanline_intensity).is_equal(0.0)
	assert_str(_stored().scanlines).is_equal("off")
	_choose(s, "number_format", 1)
	assert_int(NumberFormat.style).is_equal(NumberFormat.SCIENTIFIC)
	assert_str(_stored().number_format).is_equal("scientific")
	assert_str(s.example_label.text).is_equal("1.23e7")
	_choose(s, "number_format", 0)
	assert_str(s.example_label.text).is_equal("12.3M")
	_choose(s, "fps_cap", 0)
	assert_int(Engine.max_fps).is_equal(30)
	assert_int(_stored().fps_cap).is_equal(30)


func test_reduce_motion_dims_shake_and_scanlines_but_keeps_choice() -> void:
	var s: SettingsScreen = _screen()
	_choose(s, "shake", 2)
	_toggle(s, "reduce_motion", true)
	var shake: SettingsChoice = s.choices["shake"]
	assert_bool(shake.buttons[0].disabled).is_true()
	assert_bool((s.choices["scanlines"] as SettingsChoice).dimmed).is_true()
	assert_bool((s.choices["fps_cap"] as SettingsChoice).dimmed).is_false()
	assert_int(shake.selected).is_equal(2)
	assert_str(_stored().shake).is_equal("normal")


func test_save_and_reload_round_trip_restores_every_value() -> void:
	var s: SettingsScreen = _screen()
	_toggle(s, "muted", true)
	_toggle(s, "reduce_motion", true)
	_choose(s, "shake", 0)
	_choose(s, "scanlines", 1)
	_choose(s, "number_format", 2)
	_choose(s, "fps_cap", 0)
	SettingsActions.set_volume("sfx", 0.3)
	SettingsActions.set_volume("music", 0.15)
	s.leave()
	var reloaded: SaveService = SaveService.new(_fs, FakeClock.new(2000), "dev")
	@warning_ignore("return_value_discarded")
	reloaded.load_profile()
	var applier := SettingsApplier.new()
	var visual := VisualSettings.new()
	var audio := AudioSettings.new()
	applier.apply(PlayerSettings.from_dict(reloaded.profile.settings), visual, audio, PackedStringArray())
	assert_bool(audio.muted).is_true()
	assert_float(audio.sfx_volume).is_equal_approx(0.3, 0.0001)
	assert_float(audio.music_volume).is_equal_approx(0.15, 0.0001)
	assert_bool(visual.reduce_motion).is_true()
	assert_int(visual.screen_shake).is_equal(VisualSettings.Shake.OFF)
	assert_float(visual.scanline_intensity).is_equal(PlayerSettings.SCANLINE_VALUES[1])
	assert_int(NumberFormat.style).is_equal(NumberFormat.ENGINEERING)
	assert_int(visual.fps_cap).is_equal(30)
	Game.saves = reloaded
	var fresh: SettingsScreen = _screen()
	assert_bool((fresh.toggles["muted"] as SettingsToggle).button_pressed).is_true()


func test_session_mute_is_not_persisted_and_editing_releases_it() -> void:
	Game.settings_applier.apply(PlayerSettings.new(), Game.visual, Game.audio.settings, PackedStringArray(["--mute"]))
	var s: SettingsScreen = _screen()
	var note: Label = s._notes["muted"]
	assert_bool(note.visible).is_true()
	assert_bool((s.toggles["muted"] as SettingsToggle).button_pressed).is_true()
	SettingsActions.set_volume("sfx", 0.5)
	assert_bool(_stored().muted).is_false()
	_toggle(s, "muted", false)
	assert_bool(Game.audio.settings.muted).is_false()
	assert_bool(_stored().muted).is_false()
	assert_bool(note.visible).is_false()


func test_session_shake_and_novsync_overrides() -> void:
	Game.settings_applier.apply(
		PlayerSettings.new(),
		Game.visual,
		Game.audio.settings,
		PackedStringArray(["--shake=normal", SettingsApplier.ARG_NOVSYNC])
	)
	var s: SettingsScreen = _screen()
	assert_bool((s._notes["shake"] as Label).visible).is_true()
	assert_bool((s._notes["fps_cap"] as Label).visible).is_true()
	SettingsActions.set_volume("music", 0.4)
	assert_str(_stored().shake).is_equal("low")
	assert_int(_stored().fps_cap).is_equal(60)
	_choose(s, "shake", 0)
	assert_str(_stored().shake).is_equal("off")
	assert_bool((s._notes["shake"] as Label).visible).is_false()


func test_touch_targets_are_at_least_148() -> void:
	var s: SettingsScreen = _screen()
	for key: String in s.sliders:
		assert_float((s.sliders[key] as Control).custom_minimum_size.y).is_greater_equal(148.0)
	for key: String in s.toggles:
		assert_float((s.toggles[key] as Control).custom_minimum_size.y).is_greater_equal(148.0)
	for key: String in s.choices:
		for b: Button in (s.choices[key] as SettingsChoice).buttons:
			assert_float(b.custom_minimum_size.y).is_greater_equal(148.0)
	assert_float(s.back_button.custom_minimum_size.y).is_greater_equal(148.0)


func test_back_button_emits_and_version_is_shown() -> void:
	var s: SettingsScreen = _screen()
	var hits: Array[int] = [0]
	s.back_pressed.connect(func() -> void: hits[0] += 1)
	s.back_button.pressed.emit()
	assert_int(hits[0]).is_equal(1)
	assert_str(s.version_label.text).contains(Game.VERSION)


func test_wide_layout_is_a_1080_column() -> void:
	var s: SettingsScreen = _screen(Vector2(1990.0, 1920.0))
	assert_int(s.layout_mode()).is_equal(LayoutMode.Mode.WIDE)
	assert_float(s.content.size.x).is_equal(1080.0)
