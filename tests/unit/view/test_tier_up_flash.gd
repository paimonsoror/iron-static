class_name TestTierUpFlash
extends GdUnitTestSuite
## VT-5: the Cinder flash follows the spec 12 s8 table (modes, durations, quad counts) and stops itself.


func test_modes_follow_quality_and_reduce_motion() -> void:
	assert_int(TierUpFlash.mode_for(VisualQuality.Tier.HIGH, false)).is_equal(TierUpFlash.Mode.FULL)
	assert_int(TierUpFlash.mode_for(VisualQuality.Tier.MID, false)).is_equal(TierUpFlash.Mode.MID)
	assert_int(TierUpFlash.mode_for(VisualQuality.Tier.LOW, false)).is_equal(TierUpFlash.Mode.LOW)
	assert_int(TierUpFlash.mode_for(VisualQuality.Tier.HIGH, true)).is_equal(TierUpFlash.Mode.STEADY)
	assert_int(TierUpFlash.mode_for(VisualQuality.Tier.LOW, true)).is_equal(TierUpFlash.Mode.STEADY)


func test_durations_and_quads() -> void:
	assert_float(TierUpFlash.duration_s(TierUpFlash.Mode.FULL)).is_equal(0.45)
	assert_float(TierUpFlash.duration_s(TierUpFlash.Mode.LOW)).is_equal(0.2)
	assert_float(TierUpFlash.duration_s(TierUpFlash.Mode.STEADY)).is_equal(0.25)
	assert_int(TierUpFlash.quad_count(TierUpFlash.Mode.FULL)).is_equal(4)
	assert_int(TierUpFlash.quad_count(TierUpFlash.Mode.MID)).is_equal(2)
	assert_int(TierUpFlash.quad_count(TierUpFlash.Mode.STEADY)).is_equal(1)


func test_runs_then_hides() -> void:
	var f: TierUpFlash = auto_free(TierUpFlash.new())
	add_child(f)
	f.start(5.0, TierUpFlash.Mode.FULL)
	f.update(5.2)
	assert_bool(f.is_running()).is_true()
	assert_bool(f.visible).is_true()
	f.update(5.5)
	assert_bool(f.is_running()).is_false()
	assert_bool(f.visible).is_false()
