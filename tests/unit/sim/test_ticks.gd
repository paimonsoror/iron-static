class_name TestTicks
extends GdUnitTestSuite
## Ticks constants.


func test_wave_constants() -> void:
	assert_int(Ticks.TICK_RATE).is_equal(30)
	assert_int(Ticks.WAVE_TICKS).is_equal(720)
	assert_int(Ticks.SPAWN_TICKS).is_equal(540)
	assert_int(Ticks.LULL_TICKS).is_equal(180)
	assert_int(Ticks.SPAWN_TICKS + Ticks.LULL_TICKS).is_equal(Ticks.WAVE_TICKS)


func test_from_seconds() -> void:
	assert_int(Ticks.from_seconds(0.08)).is_equal(2)
	assert_int(Ticks.from_seconds(24.0)).is_equal(720)
	assert_int(Ticks.from_seconds(0.0)).is_equal(0)
