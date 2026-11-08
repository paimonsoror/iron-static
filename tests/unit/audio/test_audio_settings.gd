class_name TestAudioSettings
extends GdUnitTestSuite

## AudioSettings and AudioDirector plumbing (A1-03). No sound is played: the headless audio driver is a dummy.


func test_defaults_are_sensible() -> void:
	var s: AudioSettings = AudioSettings.new()
	assert_float(s.music_volume).is_equal(AudioSettings.DEFAULT_MUSIC)
	assert_float(s.sfx_volume).is_equal(1.0)
	assert_bool(s.muted).is_false()


func test_volumes_clamp_and_convert() -> void:
	var s: AudioSettings = AudioSettings.new()
	s.set_music_volume(3.0)
	s.set_sfx_volume(-1.0)
	assert_float(s.music_volume).is_equal(1.0)
	assert_float(s.sfx_volume).is_equal(0.0)
	assert_float(AudioSettings.linear_to_db_safe(0.0)).is_equal(AudioSettings.SILENT_DB)
	assert_float(AudioSettings.linear_to_db_safe(1.0)).is_equal(0.0)
	assert_float(AudioSettings.linear_to_db_safe(0.5)).is_equal_approx(-6.02, 0.01)


func test_dict_roundtrip_and_bad_input() -> void:
	var s: AudioSettings = AudioSettings.new()
	s.set_music_volume(0.25)
	s.muted = true
	var back: AudioSettings = AudioSettings.from_dict(s.to_dict())
	assert_float(back.music_volume).is_equal(0.25)
	assert_bool(back.muted).is_true()
	var junk: AudioSettings = AudioSettings.from_dict({"music": "loud", "muted": 1})
	assert_float(junk.music_volume).is_equal(AudioSettings.DEFAULT_MUSIC)
	assert_bool(junk.muted).is_false()


func test_bus_layout_has_the_four_buses_and_effects() -> void:
	for b: StringName in AudioBuses.ALL:
		assert_int(AudioBuses.index_of(b)).is_greater_equal(0)
	assert_int(AudioServer.get_bus_effect_count(AudioBuses.index_of(AudioBuses.MASTER))).is_equal(1)
	assert_int(AudioServer.get_bus_effect_count(AudioBuses.index_of(AudioBuses.MUSIC))).is_equal(1)


func test_director_skips_unknown_ids_and_pauses() -> void:
	AudioSlots.log_errors = false
	var d: AudioDirector = auto_free(AudioDirector.new())
	add_child(d)
	d.setup()
	assert_bool(d.play_sfx("no_such_sound")).is_false()
	d.pause_all()
	assert_bool(d.is_paused()).is_true()
	assert_bool(d.play_sfx("sfx_ui_tap")).is_false()
	d.resume_all()
	assert_bool(d.is_paused()).is_false()
	AudioSlots.log_errors = true
	AudioSlots.reset()


func test_director_enforces_cooldown_on_real_slot() -> void:
	var d: AudioDirector = auto_free(AudioDirector.new())
	add_child(d)
	d.setup()
	assert_bool(d.play_sfx("sfx_wave_start")).is_true()
	# same frame: cooldown 500 ms and voice cap 1 reject the repeat
	assert_bool(d.play_sfx("sfx_wave_start")).is_false()


func test_music_director_starts_and_fades() -> void:
	var d: AudioDirector = auto_free(AudioDirector.new())
	add_child(d)
	d.setup()
	d.music.setup()
	d.music.set_state(MusicState.make(12, false, 0, false))
	d.music.start()
	assert_bool(d.music.is_started()).is_true()
	assert_float(d.music.level(0)).is_equal(1.0)
	assert_float(d.music.level(1)).is_greater(0.0)
	assert_float(d.music.level(2)).is_equal(0.0)
	d.music.set_state(MusicState.make(12, true, 0, false))
	d.music._process(1.0)
	assert_float(d.music.level(2)).is_greater(0.0)
	assert_float(d.music.level(2)).is_less(0.9)
	d.music.stop()
