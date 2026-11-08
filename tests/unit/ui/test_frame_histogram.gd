class_name TestFrameHistogram
extends GdUnitTestSuite


func test_empty_is_zero() -> void:
	var h := FrameHistogram.new()
	assert_float(h.percentile(95.0)).is_equal(0.0)
	assert_int(h.count()).is_equal(0)


func test_percentile_of_uniform_samples() -> void:
	var h := FrameHistogram.new()
	for i: int in 100:
		h.add(float(i + 1))  # 1..100 ms
	assert_int(h.count()).is_equal(100)
	assert_float(h.percentile(50.0)).is_equal_approx(50.5, 0.51)
	assert_float(h.percentile(95.0)).is_equal_approx(95.5, 0.51)
	assert_float(h.maximum()).is_equal(100.0)


func test_outliers_clamp_and_reset() -> void:
	var h := FrameHistogram.new()
	h.add(5000.0)
	assert_float(h.percentile(99.0)).is_equal(FrameHistogram.MAX_MS)
	h.reset()
	assert_int(h.count()).is_equal(0)
	assert_float(h.maximum()).is_equal(0.0)
