class_name TestPlayerSettings
extends GdUnitTestSuite
## PlayerSettings (M3-10): defaults, round trip, clamping, fallbacks, unknown keys.


func test_defaults_match_runtime_defaults() -> void:
	var s: PlayerSettings = PlayerSettings.new()
	var audio: AudioSettings = AudioSettings.new()
	var visual: VisualSettings = VisualSettings.new()
	assert_float(s.music).is_equal(audio.music_volume)
	assert_float(s.sfx).is_equal(audio.sfx_volume)
	assert_bool(s.muted).is_false()
	assert_bool(s.reduce_motion).is_equal(visual.reduce_motion)
	assert_str(s.shake).is_equal(VisualSettings.SHAKE_NAMES[visual.screen_shake])
	assert_float(s.scanline_intensity()).is_equal(visual.scanline_intensity)
	assert_int(s.fps_cap).is_equal(visual.fps_cap)
	assert_int(s.number_format_style()).is_equal(NumberFormat.SHORT)
	var empty: PlayerSettings = PlayerSettings.from_dict({})
	assert_dict(empty.to_dict()).is_equal(s.to_dict())


func test_round_trip_every_key() -> void:
	var s: PlayerSettings = PlayerSettings.new()
	s.music = 0.25
	s.sfx = 0.5
	s.muted = true
	s.reduce_motion = true
	s.shake = "normal"
	s.scanlines = "low"
	s.number_format = "engineering"
	s.fps_cap = 30
	var q: PlayerSettings = PlayerSettings.from_dict(s.to_dict())
	assert_dict(q.to_dict()).is_equal(s.to_dict())
	assert_float(q.music).is_equal(0.25)
	assert_float(q.sfx).is_equal(0.5)
	assert_bool(q.muted).is_true()
	assert_bool(q.reduce_motion).is_true()
	assert_str(q.shake).is_equal("normal")
	assert_float(q.scanline_intensity()).is_equal(0.03)
	assert_int(q.number_format_style()).is_equal(NumberFormat.ENGINEERING)
	assert_int(q.fps_cap).is_equal(30)


func test_clamps_and_fallbacks() -> void:
	var q: PlayerSettings = (
		PlayerSettings
		. from_dict(
			{
				"music": 7.0,
				"sfx": -2,
				"muted": "yes",
				"reduce_motion": 1,
				"shake": "violent",
				"scanlines": 3,
				"number_format": "roman",
			}
		)
	)
	assert_float(q.music).is_equal(1.0)
	assert_float(q.sfx).is_equal(0.0)
	assert_bool(q.muted).is_false()
	assert_bool(q.reduce_motion).is_false()
	assert_str(q.shake).is_equal("low")
	assert_str(q.scanlines).is_equal("normal")
	assert_str(q.number_format).is_equal("short")


func test_fps_cap_snap_and_reject() -> void:
	assert_int(PlayerSettings.from_dict({"fps_cap": 45}).fps_cap).is_equal(60)
	assert_int(PlayerSettings.from_dict({"fps_cap": 31}).fps_cap).is_equal(30)
	assert_int(PlayerSettings.from_dict({"fps_cap": 0}).fps_cap).is_equal(60)
	assert_int(PlayerSettings.from_dict({"fps_cap": -5}).fps_cap).is_equal(60)
	assert_int(PlayerSettings.from_dict({"fps_cap": "x"}).fps_cap).is_equal(60)
	assert_int(PlayerSettings.from_dict({"fps_cap": 30.0}).fps_cap).is_equal(30)


func test_unknown_keys_kept() -> void:
	var q: PlayerSettings = PlayerSettings.from_dict({"left_handed": 2, "music": 0.3})
	var d: Dictionary = q.to_dict()
	var left_handed: int = d["left_handed"]
	var music: float = d["music"]
	assert_int(left_handed).is_equal(2)
	assert_float(music).is_equal_approx(0.3, 0.0001)


func test_enum_text_is_case_insensitive() -> void:
	assert_str(PlayerSettings.from_dict({"shake": " OFF "}).shake).is_equal("off")


func test_accessibility_defaults_and_round_trip() -> void:
	var s: PlayerSettings = PlayerSettings.from_dict({})
	assert_bool(s.haptics).is_true()
	assert_str(s.colorblind).is_equal("off")
	assert_bool(s.high_contrast).is_false()
	s.haptics = false
	s.colorblind = "tritanopia"
	s.high_contrast = true
	s.extra["future"] = 7
	var q: PlayerSettings = PlayerSettings.from_dict(s.to_dict())
	assert_bool(q.haptics).is_false()
	assert_str(q.colorblind).is_equal("tritanopia")
	assert_bool(q.high_contrast).is_true()
	var future: int = q.extra["future"]
	assert_int(future).is_equal(7)
	assert_dict(q.to_dict()).is_equal(s.to_dict())
	for key: String in ["haptics", "colorblind", "high_contrast"]:
		assert_bool(PlayerSettings.KNOWN_KEYS.has(key)).is_true()
		assert_bool(q.extra.has(key)).is_false()


func test_invalid_colorblind_falls_back_with_error_entry() -> void:
	var q: PlayerSettings = PlayerSettings.from_dict({"colorblind": "rainbow", "haptics": "yes", "high_contrast": 1})
	assert_str(q.colorblind).is_equal("off")
	assert_bool(q.haptics).is_true()
	assert_bool(q.high_contrast).is_false()
	assert_array(q.errors).has_size(1)
	assert_str(q.errors[0]).contains("rainbow")
	assert_array(PlayerSettings.from_dict({}).errors).is_empty()
	assert_str(PlayerSettings.from_dict({"colorblind": " Protanopia "}).colorblind).is_equal("protanopia")


func test_v2_fixture_loads_with_accessibility_defaults() -> void:
	var text: String = FileAccess.get_file_as_string("res://tests/fixtures/save_v2.json")
	var parsed: Variant = JSON.parse_string(text)
	assert_bool(parsed is Dictionary).is_true()
	var root: Dictionary = parsed
	var profile: Dictionary = root["profile"]
	var raw_settings: Dictionary = profile["settings"]
	var s: PlayerSettings = PlayerSettings.from_dict(raw_settings)
	assert_bool(s.haptics).is_true()
	assert_str(s.colorblind).is_equal("off")
	assert_bool(s.high_contrast).is_false()
	assert_int(s.fps_cap).is_equal(30)
