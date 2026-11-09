class_name TestSettingsApplier
extends GdUnitTestSuite
## SettingsApplier (M3-10): apply into runtime objects, session args win and are not captured.

var _saved_fps: int = 0


func before_test() -> void:
	_saved_fps = Engine.max_fps
	NumberFormat.style = NumberFormat.SHORT


func after_test() -> void:
	Engine.max_fps = _saved_fps
	NumberFormat.style = NumberFormat.SHORT


func _settings() -> PlayerSettings:
	var s: PlayerSettings = PlayerSettings.new()
	s.music = 0.4
	s.sfx = 0.8
	s.reduce_motion = true
	s.shake = "normal"
	s.scanlines = "low"
	s.number_format = "scientific"
	s.fps_cap = 30
	return s


func test_apply_sets_runtime_objects() -> void:
	var visual: VisualSettings = VisualSettings.new()
	var audio: AudioSettings = AudioSettings.new()
	var applier: SettingsApplier = SettingsApplier.new()
	var v: BigNum = BigNum.parse("1234567")
	assert_str(NumberFormat.format(v)).is_equal("1.23M")
	applier.apply(_settings(), visual, audio, PackedStringArray())
	assert_int(Engine.max_fps).is_equal(30)
	assert_float(audio.music_volume).is_equal(0.4)
	assert_float(audio.sfx_volume).is_equal(0.8)
	assert_bool(visual.reduce_motion).is_true()
	assert_int(visual.screen_shake).is_equal(VisualSettings.Shake.NORMAL)
	assert_float(visual.scanline_intensity).is_equal(0.03)
	assert_str(NumberFormat.format(v)).is_equal("1.23e6")
	assert_bool(applier.session_override.is_empty()).is_true()
	var back: PlayerSettings = applier.capture(visual, audio)
	assert_dict(back.to_dict()).is_equal(_settings().to_dict())


func test_bus_volumes_when_buses_exist() -> void:
	var idx: int = AudioBuses.index_of(AudioBuses.SFX)
	if idx < 0:
		return
	var before: float = AudioServer.get_bus_volume_db(idx)
	var visual: VisualSettings = VisualSettings.new()
	var audio: AudioSettings = AudioSettings.new()
	var s: PlayerSettings = _settings()
	SettingsApplier.new().apply(s, visual, audio, PackedStringArray())
	assert_float(AudioServer.get_bus_volume_db(idx)).is_equal_approx(linear_to_db(0.8), 0.01)
	AudioServer.set_bus_volume_db(idx, before)


func test_mute_arg_is_session_only() -> void:
	var visual: VisualSettings = VisualSettings.new()
	var audio: AudioSettings = AudioSettings.new()
	var applier: SettingsApplier = SettingsApplier.new()
	applier.apply(PlayerSettings.new(), visual, audio, PackedStringArray(["--mute"]))
	assert_bool(audio.muted).is_true()
	var master: int = AudioBuses.index_of(AudioBuses.MASTER)
	if master >= 0:
		assert_bool(AudioServer.is_bus_mute(master)).is_true()
		AudioServer.set_bus_mute(master, false)
	assert_bool(applier.is_overridden("muted")).is_true()
	assert_bool(applier.capture(visual, audio).muted).is_false()
	applier.release_override("muted")
	assert_bool(applier.capture(visual, audio).muted).is_true()


func test_novsync_is_session_only() -> void:
	var visual: VisualSettings = VisualSettings.new()
	var audio: AudioSettings = AudioSettings.new()
	var applier: SettingsApplier = SettingsApplier.new()
	applier.apply(PlayerSettings.new(), visual, audio, PackedStringArray(["--debug-novsync"]))
	assert_int(Engine.max_fps).is_equal(0)
	assert_int(visual.fps_cap).is_equal(0)
	assert_int(applier.capture(visual, audio).fps_cap).is_equal(60)


func test_shake_and_quality_args_win() -> void:
	var visual: VisualSettings = VisualSettings.new()
	var audio: AudioSettings = AudioSettings.new()
	var applier: SettingsApplier = SettingsApplier.new()
	var s: PlayerSettings = PlayerSettings.new()
	s.shake = "low"
	applier.apply(s, visual, audio, PackedStringArray(["--shake=off", "--quality=low"]))
	assert_int(visual.screen_shake).is_equal(VisualSettings.Shake.OFF)
	assert_str(visual.quality.tier_name()).is_equal("low")
	assert_bool(applier.is_overridden("quality")).is_true()
	assert_str(applier.capture(visual, audio).shake).is_equal("low")


func test_accessibility_applies_hook_and_haptics() -> void:
	var visual: VisualSettings = VisualSettings.new()
	var audio: AudioSettings = AudioSettings.new()
	var applier: SettingsApplier = SettingsApplier.new()
	var h: Haptics = Haptics.new()
	applier.haptics = h
	var changes: Array[int] = [0]
	visual.accessibility_changed.connect(func() -> void: changes[0] += 1)
	var s: PlayerSettings = PlayerSettings.new()
	s.haptics = false
	s.colorblind = "deuteranopia"
	s.high_contrast = true
	applier.apply(s, visual, audio, PackedStringArray())
	assert_bool(h.enabled).is_false()
	assert_str(visual.colorblind).is_equal("deuteranopia")
	assert_bool(visual.high_contrast).is_true()
	assert_int(changes[0]).is_equal(1)
	var back: PlayerSettings = applier.capture(visual, audio)
	assert_bool(back.haptics).is_false()
	assert_str(back.colorblind).is_equal("deuteranopia")
	assert_bool(back.high_contrast).is_true()
	applier.apply(PlayerSettings.new(), visual, audio, PackedStringArray())
	assert_bool(h.enabled).is_true()
	assert_str(visual.colorblind).is_equal("off")


func test_set_accessibility_rejects_unknown_mode() -> void:
	var visual: VisualSettings = VisualSettings.new()
	visual.set_accessibility("bogus", false)
	assert_str(visual.colorblind).is_equal("off")
