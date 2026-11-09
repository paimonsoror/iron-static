class_name TestHaptics
extends GdUnitTestSuite
## Haptics service and hooks (M4-22): patterns, rate limit, switch, desktop no-op.

var _now: int = 0


func _make() -> Array:
	var h: Haptics = Haptics.new()
	var sink: RecordingHapticsSink = RecordingHapticsSink.new()
	h.sink = sink
	_now = 1000
	h.clock = func() -> int: return _now
	return [h, sink]


func test_patterns() -> void:
	var made: Array = _make()
	var h: Haptics = made[0]
	var sink: RecordingHapticsSink = made[1]
	h.boss_spawn()
	_now += 100
	h.death()
	_now += 100
	h.draft_pick()
	_now += 100
	h.buy()
	assert_array(Array(sink.durations())).is_equal([80, 250, 25, 15])


func test_fifty_buys_in_two_seconds_give_at_most_six_pulses() -> void:
	var made: Array = _make()
	var h: Haptics = made[0]
	var sink: RecordingHapticsSink = made[1]
	for i: int in 50:
		h.buy()
		_now += 40
	assert_int(sink.pulses.size()).is_between(1, 6)
	assert_int(sink.pulses.size()).is_equal(5)


func test_new_streak_after_gap_ticks_again() -> void:
	var made: Array = _make()
	var h: Haptics = made[0]
	var sink: RecordingHapticsSink = made[1]
	h.buy()
	_now += 40
	h.buy()
	_now += Haptics.BUY_GAP_MS + 10
	h.buy()
	assert_int(sink.pulses.size()).is_equal(2)


func test_global_rate_limit_drops_close_pulses_but_not_death() -> void:
	var made: Array = _make()
	var h: Haptics = made[0]
	var sink: RecordingHapticsSink = made[1]
	h.draft_pick()
	_now += 10
	h.draft_pick()
	assert_int(sink.pulses.size()).is_equal(1)
	h.death()
	assert_int(sink.pulses.size()).is_equal(2)


func test_disabled_is_silent() -> void:
	var made: Array = _make()
	var h: Haptics = made[0]
	var sink: RecordingHapticsSink = made[1]
	h.enabled = false
	h.buy()
	h.boss_spawn()
	h.death()
	h.draft_pick()
	assert_int(sink.pulses.size()).is_equal(0)


func test_enabled_by_default_and_desktop_sink_is_noop() -> void:
	var h: Haptics = Haptics.new()
	assert_bool(h.enabled).is_true()
	var s: HapticsSink = Haptics.platform_sink()
	if not OS.has_feature("android"):
		assert_bool(s is DeviceHapticsSink).is_false()
	h.death()  # base sink: must not crash


func test_hooks_route_events() -> void:
	var made: Array = _make()
	var h: Haptics = made[0]
	var sink: RecordingHapticsSink = made[1]
	var hooks: HapticHooks = HapticHooks.new(h)
	hooks.route(SimEventKind.SHOT_FIRED)
	hooks.route(SimEventKind.ENEMY_KILLED)
	hooks.route(SimEventKind.CINDER_HIT)
	assert_int(sink.pulses.size()).is_equal(0)
	hooks.route(SimEventKind.UPGRADE_BOUGHT)
	_now += 100
	hooks.route(SimEventKind.BOSS_SPAWNED)
	_now += 100
	hooks.route(SimEventKind.RUN_ENDED)
	_now += 100
	hooks.draft_pick()
	assert_array(Array(sink.durations())).is_equal([15, 80, 250, 25])
