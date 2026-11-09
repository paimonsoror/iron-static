class_name TestHapticsTierUp
extends GdUnitTestSuite
## VT-5 / spec Q7: the tier pulse replaces the buy tick of the purchase that reaches a new visual tier.

var _now: int = 1000
var _haptics: Haptics
var _sink: RecordingHapticsSink
var _world: SimWorld
var _hooks: HapticHooks


func before_test() -> void:
	_now = 1000
	_haptics = Haptics.new()
	_sink = RecordingHapticsSink.new()
	_haptics.sink = _sink
	_haptics.clock = func() -> int: return _now
	_world = SimWorld.new(SimConfigLoader.load_default(1))
	_hooks = HapticHooks.new(_haptics)
	_hooks.bind(_world)


func _buy(row: int, level: int) -> void:
	_hooks.route(SimEventKind.UPGRADE_BOUGHT, row, level)


func test_mk2_and_mk3_pulse_replaces_the_tick() -> void:
	_buy(0, 5)
	assert_array(Array(_sink.pulses)).is_equal([Vector2(35.0, 0.6)])
	_now += 500
	_buy(0, 12)
	assert_int(_sink.pulses.size()).is_equal(2)
	assert_array(Array(_sink.pulses)).is_equal([Vector2(35.0, 0.6), Vector2(35.0, 0.6)])


func test_mk4_pulse_is_longer_and_stronger() -> void:
	_buy(0, 25)
	assert_array(Array(_sink.pulses)).is_equal([Vector2(70.0, 0.8)])


func test_a_plain_buy_still_ticks() -> void:
	_buy(0, 3)
	assert_array(Array(_sink.pulses)).is_equal([Vector2(15.0, 0.4)])


func test_tier_pulse_is_not_dropped_by_the_rate_limit() -> void:
	_buy(0, 4)  # tick
	_now += 20  # inside MIN_GAP_MS of the tick
	_buy(0, 5)  # tier pulse must still play, and no second tick follows
	assert_array(Array(_sink.pulses)).is_equal([Vector2(15.0, 0.4), Vector2(35.0, 0.6)])


func test_tier_pulse_honors_the_haptics_switch() -> void:
	_haptics.enabled = false
	_buy(0, 5)
	assert_int(_sink.pulses.size()).is_equal(0)


func test_owned_levels_at_bind_and_skip_do_not_pulse() -> void:
	_world.run_levels[0] = 12
	_hooks.bind(_world)
	_buy(0, 13)
	assert_array(Array(_sink.pulses)).is_equal([Vector2(15.0, 0.4)])  # a normal tick, no tier pulse
	_world.run_levels[0] = 30
	_hooks.skip()
	_now += 500
	_buy(0, 31)
	assert_int(_sink.pulses.size()).is_equal(2)
	assert_float(_sink.pulses[1].x).is_equal(15.0)
