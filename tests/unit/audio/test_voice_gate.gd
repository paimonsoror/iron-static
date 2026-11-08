class_name TestVoiceGate
extends GdUnitTestSuite

## VoiceGate (A1-03): voice cap and cooldown, plus the buy pitch ramp.


func test_voice_cap_limits_simultaneous_voices() -> void:
	var g: VoiceGate = VoiceGate.new(2, 0)
	assert_int(g.acquire(0, 100)).is_equal(0)
	assert_int(g.acquire(10, 100)).is_equal(1)
	assert_int(g.acquire(20, 100)).is_equal(-1)
	assert_int(g.active(20)).is_equal(2)
	# voice 0 ended at 100
	assert_int(g.acquire(100, 100)).is_equal(0)
	assert_int(g.active(105)).is_equal(2)
	assert_int(g.active(150)).is_equal(1)
	assert_int(g.active(1000)).is_equal(0)


func test_cooldown_blocks_close_starts() -> void:
	var g: VoiceGate = VoiceGate.new(4, 50)
	assert_int(g.acquire(0, 500)).is_equal(0)
	assert_int(g.acquire(49, 500)).is_equal(-1)
	assert_int(g.acquire(50, 500)).is_equal(1)
	# a skipped sound does not restart the cooldown
	assert_int(g.acquire(99, 500)).is_equal(-1)
	assert_int(g.acquire(100, 500)).is_equal(2)


func test_clear_frees_everything_and_cap_floor() -> void:
	var g: VoiceGate = VoiceGate.new(0, 0)
	assert_int(g.voice_cap).is_equal(1)
	assert_int(g.acquire(0, 1000)).is_equal(0)
	assert_int(g.acquire(1, 1000)).is_equal(-1)
	g.clear()
	assert_int(g.acquire(2, 1000)).is_equal(0)


func test_high_rate_stream_is_throttled() -> void:
	# 20 requests per second against cooldown 45 ms and cap 3 of 130 ms sounds: well under 20 voices per second
	var g: VoiceGate = VoiceGate.new(3, 45)
	var played: int = 0
	for i: int in range(40):
		if g.acquire(i * 25, 130) >= 0:
			played += 1
	assert_int(played).is_between(10, 20)


func test_buy_pitch_ramp_steps_caps_and_resets() -> void:
	var r: BuyPitchRamp = BuyPitchRamp.new()
	assert_float(r.next_semitones(0)).is_equal(0.0)
	assert_float(r.next_semitones(100)).is_equal(BuyPitchRamp.STEP_SEMITONES)
	assert_float(r.next_semitones(200)).is_equal(BuyPitchRamp.STEP_SEMITONES * 2.0)
	var last: float = 0.0
	for i: int in range(40):
		last = r.next_semitones(300 + i * 50)
	assert_float(last).is_equal(BuyPitchRamp.MAX_SEMITONES)
	# a gap longer than the reset window starts over
	assert_float(r.next_semitones(300 + 40 * 50 + BuyPitchRamp.RESET_GAP_MS + 1)).is_equal(0.0)
	assert_float(r.next_semitones(5000)).is_equal(0.0)
	@warning_ignore("return_value_discarded")
	r.next_semitones(5050)
	r.reset()
	assert_float(r.next_semitones(5060)).is_equal(0.0)


func test_pitch_scale_of_semitones() -> void:
	assert_float(BuyPitchRamp.pitch_scale(0.0)).is_equal(1.0)
	assert_float(BuyPitchRamp.pitch_scale(12.0)).is_equal_approx(2.0, 0.0001)
	assert_float(BuyPitchRamp.pitch_scale(BuyPitchRamp.MAX_SEMITONES)).is_less(1.35)
