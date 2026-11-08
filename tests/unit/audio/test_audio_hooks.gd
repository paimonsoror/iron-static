class_name TestAudioHooks
extends GdUnitTestSuite
## AudioHooks routing, the --mute switch and a disabled director.

var _spy: SpyAudioDirector


func before_test() -> void:
	_spy = auto_free(SpyAudioDirector.new())
	AudioHooks.override = _spy


func after_test() -> void:
	AudioHooks.override = null


func test_hooks_route_to_the_director() -> void:
	AudioHooks.tap()
	AudioHooks.deny()
	AudioHooks.buy_step()
	AudioHooks.buy_end()
	AudioHooks.pause_audio()
	AudioHooks.resume_audio()
	assert_array(_spy.log).contains_exactly(["sfx_ui_tap", "sfx_ui_deny", "buy_step", "buy_end", "pause", "resume"])


func test_mute_arg() -> void:
	assert_bool(AudioSettings.is_mute_arg(PackedStringArray(["--mute"]))).is_true()
	assert_bool(AudioSettings.is_mute_arg(PackedStringArray(["--quality=low"]))).is_false()


func test_disabled_director_plays_nothing() -> void:
	var d: AudioDirector = auto_free(AudioDirector.new())
	d.disabled = true
	assert_bool(d.play_sfx("sfx_ui_tap")).is_false()
	d.start_music()  # no music node, must not crash
	d.set_music_state(MusicState.make(1, false, 0, false))


func test_real_director_starts_music_once_and_follows_state() -> void:
	var d: AudioDirector = auto_free(AudioDirector.new())
	add_child(d)
	d.setup()
	d.set_music_state(MusicState.make(12, false, 0, false))
	d.start_music()
	d.start_music()
	assert_bool(d.music.is_started()).is_true()
	assert_float(d.music.level(0)).is_equal(1.0)
	assert_float(d.music.level(1)).is_equal_approx(0.9, 0.001)
	assert_float(d.music.level(2)).is_equal(0.0)
	d.set_music_state(MusicState.make(1, true, 0, false))
	d.music.stop()
