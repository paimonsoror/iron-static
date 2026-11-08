class_name TestAmbience
extends GdUnitTestSuite

## M3-31 title ambience: slot rows, exact loop lengths, AmbienceDirector fades, AudioDirector menu API.

const SAMPLE_RATE: float = 44100.0
const WIND_SAMPLES: int = 1587600  # 36 s
const CREAK_SAMPLES: int = 2293200  # 52 s


func before_test() -> void:
	AudioSlots.reset()
	AudioSlots.log_errors = false


func after_test() -> void:
	AudioSlots.log_errors = true
	AudioSlots.reset()


func test_ambience_slot_rows_load() -> void:
	for sid: String in AmbienceDirector.LAYERS:
		assert_bool(AudioSlots.has(sid)).is_true()
		var s: AudioSlot = AudioSlots.slot(sid)
		assert_bool(s.is_ambience()).is_true()
		assert_bool(s.is_music()).is_false()
		assert_str(s.bus).is_equal("SFX")
		assert_int(s.voice_cap).is_equal(1)
		assert_float(s.pitch_var).is_equal(0.0)
		# far below the music layers (0 dB trims, menu pad about -26 LUFS-ish)
		assert_float(s.volume_db).is_less(-5.0)
		assert_object(AudioSlots.stream(sid)).is_not_null()
	assert_int(AudioSlots.error_count).is_equal(0)


func test_loop_lengths_are_exact() -> void:
	var wind: AudioStream = AudioSlots.stream("amb_wasteland_wind")
	var creak: AudioStream = AudioSlots.stream("amb_metal_creak")
	assert_float(wind.get_length() * SAMPLE_RATE).is_equal_approx(float(WIND_SAMPLES), 2.0)
	assert_float(creak.get_length() * SAMPLE_RATE).is_equal_approx(float(CREAK_SAMPLES), 2.0)


func test_start_fades_in_and_stop_fades_out_then_halts() -> void:
	var amb: AmbienceDirector = auto_free(AmbienceDirector.new())
	add_child(amb)
	assert_bool(amb.is_active()).is_false()
	amb.start()
	assert_bool(amb.is_active()).is_true()
	assert_bool(amb.is_playing()).is_true()
	assert_float(amb.level()).is_equal(0.0)
	amb._process(AmbienceDirector.FADE_IN_S * 0.5)
	assert_float(amb.level()).is_equal_approx(0.5, 0.001)
	amb._process(AmbienceDirector.FADE_IN_S)
	assert_float(amb.level()).is_equal(1.0)
	amb.stop()
	assert_bool(amb.is_active()).is_false()
	assert_bool(amb.is_playing()).is_true()  # the fade-out tail still sounds
	amb._process(AmbienceDirector.FADE_OUT_S * 0.5)
	assert_bool(amb.is_playing()).is_true()
	amb._process(AmbienceDirector.FADE_OUT_S)
	assert_float(amb.level()).is_equal(0.0)
	assert_bool(amb.is_playing()).is_false()


func test_restart_during_fade_out_keeps_playing() -> void:
	var amb: AmbienceDirector = auto_free(AmbienceDirector.new())
	add_child(amb)
	amb.start()
	amb._process(AmbienceDirector.FADE_IN_S)
	amb.stop()
	amb._process(AmbienceDirector.FADE_OUT_S * 0.5)
	amb.start()
	amb._process(AmbienceDirector.FADE_IN_S)
	assert_bool(amb.is_playing()).is_true()
	assert_float(amb.level()).is_equal(1.0)
	amb.stop_now()
	assert_bool(amb.is_playing()).is_false()
	assert_float(amb.level()).is_equal(0.0)


func test_director_menu_api_toggles_and_battle_start_stops() -> void:
	var d: AudioDirector = auto_free(AudioDirector.new())
	add_child(d)
	d.setup()
	assert_bool(d.is_menu_ambience_active()).is_false()
	d.start_menu_audio()
	assert_bool(d.is_menu_ambience_active()).is_true()
	assert_bool(d.music.state.in_menu).is_true()
	d.set_music_state(MusicState.make(0, false, 0, true))  # the results screen does not stop or restart it
	assert_bool(d.is_menu_ambience_active()).is_true()
	d.set_music_state(MusicState.make(1, false, 0, false))  # battle start
	assert_bool(d.is_menu_ambience_active()).is_false()
	d.set_music_state(MusicState.make(0, false, 0, true))  # back at the menu: not restarted by the state alone
	assert_bool(d.is_menu_ambience_active()).is_false()
	d.start_menu_audio()
	assert_bool(d.is_menu_ambience_active()).is_true()
	d.stop_menu_audio()
	assert_bool(d.is_menu_ambience_active()).is_false()
	d.music.stop()
	d.ambience.stop_now()


func test_mute_silences_the_menu_audio() -> void:
	var d: AudioDirector = auto_free(AudioDirector.new())
	add_child(d)
	d.setup()
	d.disabled = true
	d.start_menu_audio()
	assert_bool(d.is_menu_ambience_active()).is_false()
	assert_bool(d.ambience.is_playing()).is_false()
	assert_bool(d.music.is_started()).is_false()


func test_spy_records_the_menu_calls() -> void:
	var spy: SpyAudioDirector = auto_free(SpyAudioDirector.new())
	spy.start_menu_audio()
	assert_bool(spy.is_menu_ambience_active()).is_true()
	spy.stop_menu_audio()
	assert_bool(spy.is_menu_ambience_active()).is_false()
	assert_array(spy.log).is_equal(["menu_audio_start", "menu_audio_stop"])
