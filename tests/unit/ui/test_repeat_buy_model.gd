class_name TestRepeatBuyModel
extends GdUnitTestSuite
## RepeatBuyModel (V1-25): hold time -> purchase steps, only counts 1 / 10 / 100.


func test_nothing_before_the_first_repeat() -> void:
	var m := RepeatBuyModel.new()
	assert_int(m.poll(0.0).x).is_equal(0)
	assert_int(m.poll(RepeatBuyModel.FIRST_S - 0.01).x).is_equal(0)


func test_first_repeat_at_0_35_s_buys_one() -> void:
	var m := RepeatBuyModel.new()
	var d: Vector2i = m.poll(RepeatBuyModel.FIRST_S)
	assert_int(d.x).is_equal(1)
	assert_int(d.y).is_equal(1)
	assert_int(m.poll(RepeatBuyModel.FIRST_S + 0.1).x).is_equal(0)


func test_interval_eases_from_slow_to_fast_and_holds() -> void:
	assert_float(RepeatBuyModel.interval_at(0.35)).is_equal_approx(0.25, 0.0001)
	assert_float(RepeatBuyModel.interval_at(1.35)).is_equal_approx(0.15, 0.0001)
	assert_float(RepeatBuyModel.interval_at(2.35)).is_equal_approx(0.05, 0.0001)
	assert_float(RepeatBuyModel.interval_at(9.0)).is_equal_approx(0.05, 0.0001)


func test_steps_accelerate_and_batches_are_only_1_10_100() -> void:
	var m := RepeatBuyModel.new()
	var t: float = 0.0
	var per_second: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
	while t < 8.0:
		t += 1.0 / 60.0
		var d: Vector2i = m.poll(t)
		assert_bool([1, 10, 100].has(d.y)).is_true()
		per_second[mini(int(t), 7)] += d.x
	assert_int(per_second[1]).is_greater(per_second[0])
	assert_int(per_second[3]).is_greater(per_second[1])
	assert_int(RepeatBuyModel.batch_at(2.9)).is_equal(1)
	assert_int(RepeatBuyModel.batch_at(3.0)).is_equal(10)
	assert_int(RepeatBuyModel.batch_at(6.0)).is_equal(100)


func test_a_long_frame_returns_several_steps_and_reset_restarts() -> void:
	var m := RepeatBuyModel.new()
	assert_int(m.poll(1.5).x).is_greater(2)
	m.reset()
	assert_int(m.poll(0.2).x).is_equal(0)
	assert_int(m.poll(0.36).x).is_equal(1)
