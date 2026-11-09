class_name TestSimRunArgs
extends GdUnitTestSuite
## SimRunArgs: flag parsing and nearest-rank percentiles for tools/sim_run.gd.


func test_defaults() -> void:
	var a: SimRunArgs = SimRunArgs.parse(PackedStringArray())
	assert_str(a.error).is_empty()
	assert_int(a.runs).is_equal(20)
	assert_int(a.seed_value).is_equal(1)
	assert_int(a.max_waves).is_equal(200)


func test_all_flags() -> void:
	var a: SimRunArgs = SimRunArgs.parse(PackedStringArray(["--runs", "5", "--seed", "-3", "--max-waves", "40"]))
	assert_str(a.error).is_empty()
	assert_int(a.runs).is_equal(5)
	assert_int(a.seed_value).is_equal(-3)
	assert_int(a.max_waves).is_equal(40)


func test_unknown_flag_is_an_error() -> void:
	var a: SimRunArgs = SimRunArgs.parse(PackedStringArray(["--bogus"]))
	assert_str(a.error).contains("--bogus")


func test_bad_values_are_errors() -> void:
	assert_str(SimRunArgs.parse(PackedStringArray(["--runs"])).error).is_not_empty()
	assert_str(SimRunArgs.parse(PackedStringArray(["--runs", "x"])).error).is_not_empty()
	assert_str(SimRunArgs.parse(PackedStringArray(["--runs", "0"])).error).is_not_empty()
	assert_str(SimRunArgs.parse(PackedStringArray(["--max-waves", "0"])).error).is_not_empty()


func test_percentile_nearest_rank() -> void:
	var v: PackedInt32Array = PackedInt32Array([9, 1, 5, 3, 7, 2, 8, 4, 6, 10])
	assert_int(SimRunArgs.percentile(v, 10)).is_equal(1)
	assert_int(SimRunArgs.percentile(v, 50)).is_equal(5)
	assert_int(SimRunArgs.percentile(v, 90)).is_equal(9)
	assert_int(SimRunArgs.percentile(PackedInt32Array(), 50)).is_equal(0)
	assert_int(SimRunArgs.percentile(PackedInt32Array([4]), 90)).is_equal(4)


func test_foundry_and_frame_flags() -> void:
	var a: SimRunArgs = SimRunArgs.parse(PackedStringArray(["--foundry", "laser_output=5", "--frame", "striker"]))
	assert_str(a.error).is_empty()
	assert_str(a.foundry).is_equal("laser_output=5")
	assert_str(a.frame).is_equal("striker")
	assert_str(SimRunArgs.parse(PackedStringArray(["--frame"])).error).is_not_empty()
	assert_float(SimRunArgs.mean(PackedInt32Array([8, 9, 10, 9]))).is_equal(9.0)
