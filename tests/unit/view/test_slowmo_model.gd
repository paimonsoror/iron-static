class_name TestSlowmoModel
extends GdUnitTestSuite
## V1-14: slow-mo factor curve and gating.


func test_boss_curve() -> void:
	var k: SlowmoModel.Kind = SlowmoModel.Kind.BOSS_DEATH
	assert_float(SlowmoModel.factor_at(k, 0.0)).is_equal(1.0)
	assert_float(SlowmoModel.factor_at(k, 0.025)).is_equal_approx(0.675, 1.0e-6)
	assert_float(SlowmoModel.factor_at(k, 0.05)).is_equal_approx(0.35, 1.0e-6)
	assert_float(SlowmoModel.factor_at(k, 0.2)).is_equal_approx(0.35, 1.0e-6)
	assert_float(SlowmoModel.factor_at(k, 0.4)).is_equal(1.0)
	assert_float(SlowmoModel.factor_at(k, 0.41)).is_equal(1.0)


func test_cinder_curve() -> void:
	var k: SlowmoModel.Kind = SlowmoModel.Kind.CINDER_DEATH
	assert_float(SlowmoModel.factor_at(k, 0.3)).is_equal_approx(0.25, 1.0e-6)
	assert_float(SlowmoModel.factor_at(k, 0.79)).is_equal_approx(0.25, 1.0e-6)
	assert_float(SlowmoModel.factor_at(k, 0.8)).is_equal(1.0)


func test_step_runs_and_ends() -> void:
	var m := SlowmoModel.new()
	assert_float(m.step(0.016, 1, false)).is_equal(1.0)
	m.trigger(SlowmoModel.Kind.BOSS_DEATH)
	assert_float(m.step(0.1, 1, false)).is_equal_approx(0.35, 1.0e-6)
	assert_float(m.step(0.31, 1, false)).is_equal(1.0)
	assert_int(m.kind).is_equal(SlowmoModel.Kind.NONE)


func test_off_under_reduce_motion_and_above_2x() -> void:
	var m := SlowmoModel.new()
	m.trigger(SlowmoModel.Kind.BOSS_DEATH)
	assert_float(m.step(0.1, 1, true)).is_equal(1.0)
	m.trigger(SlowmoModel.Kind.BOSS_DEATH)
	assert_float(m.step(0.1, 3, false)).is_equal(1.0)
	m.trigger(SlowmoModel.Kind.BOSS_DEATH)
	assert_float(m.step(0.1, 2, false)).is_equal_approx(0.35, 1.0e-6)


func test_cinder_death_not_replaced_by_boss_death() -> void:
	var m := SlowmoModel.new()
	m.trigger(SlowmoModel.Kind.CINDER_DEATH)
	m.trigger(SlowmoModel.Kind.BOSS_DEATH)
	assert_int(m.kind).is_equal(SlowmoModel.Kind.CINDER_DEATH)
