class_name TestSettingsLaser
extends GdUnitTestSuite
## Settings > LASER SOUND (v0.5.1): the toggle flips `AudioSettings.laser_sound` live and is saved with the profile.

var _fs: MemorySaveFs
var _old_saves: SaveService
var _old_settings: PlayerSettings


func before_test() -> void:
	SaveKey.reset()
	_old_saves = Game.saves
	_old_settings = Game.settings_applier.capture(Game.visual, Game.audio.settings)
	_fs = MemorySaveFs.new()
	var svc: SaveService = SaveService.new(_fs, FakeClock.new(1000), "dev")
	@warning_ignore("return_value_discarded")
	svc.load_profile()
	Game.saves = svc
	Game.settings_applier.apply(PlayerSettings.new(), Game.visual, Game.audio.settings, PackedStringArray())


func after_test() -> void:
	Game.settings_applier.apply(_old_settings, Game.visual, Game.audio.settings, PackedStringArray())
	Game.saves = _old_saves


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


func test_toggle_applies_live_and_persists() -> void:
	var s: SettingsScreen = _screen()
	var t: SettingsToggle = s.toggles["laser"]
	assert_bool(t.button_pressed).is_true()
	assert_bool(Game.audio.settings.laser_sound).is_true()
	t.button_pressed = false
	assert_bool(Game.audio.settings.laser_sound).is_false()
	assert_bool(_stored().laser).is_false()
	assert_bool(_stored().muted).is_false()
	s.enter()
	assert_bool(t.button_pressed).is_false()
	assert_float(t.custom_minimum_size.y).is_greater_equal(148.0)
	t.button_pressed = true
	assert_bool(Game.audio.settings.laser_sound).is_true()
	assert_bool(_stored().laser).is_true()


func test_saved_off_state_is_applied_on_load() -> void:
	var ps: PlayerSettings = PlayerSettings.new()
	ps.laser = false
	Game.settings_applier.apply(ps, Game.visual, Game.audio.settings, PackedStringArray())
	assert_bool(Game.audio.settings.laser_sound).is_false()
	var s: SettingsScreen = _screen()
	assert_bool((s.toggles["laser"] as SettingsToggle).button_pressed).is_false()
