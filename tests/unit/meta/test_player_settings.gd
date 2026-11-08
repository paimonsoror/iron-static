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
	var q: PlayerSettings = PlayerSettings.from_dict({"haptics": 2, "music": 0.3})
	var d: Dictionary = q.to_dict()
	var haptics: int = d["haptics"]
	var music: float = d["music"]
	assert_int(haptics).is_equal(2)
	assert_float(music).is_equal_approx(0.3, 0.0001)


func test_enum_text_is_case_insensitive() -> void:
	assert_str(PlayerSettings.from_dict({"shake": " OFF "}).shake).is_equal("off")
