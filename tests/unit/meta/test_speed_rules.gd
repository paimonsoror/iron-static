class_name TestSpeedRules
extends GdUnitTestSuite
## R1-03: speed unlock gates, cycle order, fall-back hysteresis and the high-speed load factors.


func test_unlock_gates_follow_the_best_timed_wave() -> void:
	assert_array(SpeedRules.unlocked(0)).is_equal([1, 2])
	assert_array(SpeedRules.unlocked(29)).is_equal([1, 2])
	assert_array(SpeedRules.unlocked(30)).is_equal([1, 2, 4])
	assert_array(SpeedRules.unlocked(59)).is_equal([1, 2, 4])
	assert_array(SpeedRules.unlocked(60)).is_equal([1, 2, 4, 8])
	assert_bool(SpeedRules.is_unlocked(8, 59)).is_false()
	assert_bool(SpeedRules.is_unlocked(8, 60)).is_true()


func test_next_unlock_names_the_next_locked_speed() -> void:
	assert_object(SpeedRules.next_unlock(0)).is_equal(Vector2i(4, 30))
	assert_object(SpeedRules.next_unlock(30)).is_equal(Vector2i(8, 60))
	assert_object(SpeedRules.next_unlock(60)).is_equal(Vector2i.ZERO)


func test_cycle_visits_only_unlocked_speeds_and_wraps() -> void:
	assert_int(SpeedRules.cycle_next(1, 0)).is_equal(2)
	assert_int(SpeedRules.cycle_next(2, 0)).is_equal(1)
	assert_int(SpeedRules.cycle_next(2, 30)).is_equal(4)
	assert_int(SpeedRules.cycle_next(4, 30)).is_equal(1)
	assert_int(SpeedRules.cycle_next(4, 60)).is_equal(8)
	assert_int(SpeedRules.cycle_next(8, 60)).is_equal(1)
	assert_int(SpeedRules.cycle_next(8, 0)).is_equal(1)  # a locked value restarts at 1x


func test_fall_back_hysteresis() -> void:
	var f: bool = false
	f = SpeedRules.next_fallen(f, 8, 0.80, false)
	assert_bool(f).is_false()
	f = SpeedRules.next_fallen(f, 8, 0.749, false)
	assert_bool(f).is_true()
	assert_int(SpeedRules.effective(8, f)).is_equal(2)
	f = SpeedRules.next_fallen(f, 8, 0.78, false)  # between 75% and 80%: keeps the state
	assert_bool(f).is_true()
	f = SpeedRules.next_fallen(f, 8, 0.80, false)
	assert_bool(f).is_false()
	f = SpeedRules.next_fallen(f, 8, 0.78, false)  # not fallen: stays up between the thresholds
	assert_bool(f).is_false()
	assert_int(SpeedRules.effective(8, f)).is_equal(8)


func test_boss_forces_and_holds_the_fall_back() -> void:
	var f: bool = SpeedRules.next_fallen(false, 4, 1.0, true)
	assert_bool(f).is_true()
	f = SpeedRules.next_fallen(f, 4, 1.0, true)  # full hull, boss alive: still 2x
	assert_bool(f).is_true()
	f = SpeedRules.next_fallen(f, 4, 1.0, false)
	assert_bool(f).is_false()


func test_no_fall_back_at_or_below_2x() -> void:
	assert_bool(SpeedRules.next_fallen(true, 2, 0.1, true)).is_false()
	assert_bool(SpeedRules.next_fallen(false, 1, 0.1, true)).is_false()
	assert_int(SpeedRules.effective(2, true)).is_equal(2)
	assert_int(SpeedRules.effective(1, true)).is_equal(1)


func test_speed_load_factors() -> void:
	assert_int(SpeedLoad.scaled(3, 1)).is_equal(3)
	assert_int(SpeedLoad.scaled(3, 2)).is_equal(3)
	assert_int(SpeedLoad.scaled(3, 4)).is_equal(2)
	assert_int(SpeedLoad.scaled(3, 8)).is_equal(1)
	assert_int(SpeedLoad.scaled(1, 8)).is_equal(1)  # never below 1 for a positive count
	assert_int(SpeedLoad.scaled(0, 8)).is_equal(0)
	assert_int(SpeedLoad.scaled(24, 8)).is_equal(6)
