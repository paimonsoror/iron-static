class_name TestBalanceRunArgs
extends GdUnitTestSuite
## BalanceRunArgs: flag parsing and target status bands for tools/balance_run.gd.


func test_defaults() -> void:
	var a: BalanceRunArgs = BalanceRunArgs.parse(PackedStringArray())
	assert_str(a.error).is_empty()
	assert_str(a.profile).is_equal("fresh")
	assert_int(a.waves).is_equal(100)
	assert_int(a.runs).is_equal(20)
	assert_int(a.seed_value).is_equal(1)
	assert_str(a.policy).is_equal("greedy4")
	assert_int(a.sector).is_equal(1)


func test_all_flags() -> void:
	var raw: PackedStringArray = PackedStringArray(
		["--profile", "p.json", "--waves", "50", "--runs", "3", "--seed", "-2", "--policy", "all", "--sector", "2"]
	)
	var a: BalanceRunArgs = BalanceRunArgs.parse(raw)
	assert_str(a.error).is_empty()
	assert_str(a.profile).is_equal("p.json")
	assert_int(a.waves).is_equal(50)
	assert_int(a.runs).is_equal(3)
	assert_int(a.seed_value).is_equal(-2)
	assert_str(a.policy).is_equal("all")
	assert_int(a.sector).is_equal(2)


func test_unknown_flag_is_an_error() -> void:
	assert_str(BalanceRunArgs.parse(PackedStringArray(["--bogus"])).error).contains("--bogus")
	assert_str(BalanceRunArgs.parse(PackedStringArray(["-Profile", "fresh"])).error).is_not_empty()


func test_bad_values_are_errors() -> void:
	assert_str(BalanceRunArgs.parse(PackedStringArray(["--runs"])).error).is_not_empty()
	assert_str(BalanceRunArgs.parse(PackedStringArray(["--runs", "x"])).error).is_not_empty()
	assert_str(BalanceRunArgs.parse(PackedStringArray(["--waves", "0"])).error).is_not_empty()
	assert_str(BalanceRunArgs.parse(PackedStringArray(["--policy", "nope"])).error).is_not_empty()
	assert_str(BalanceRunArgs.parse(PackedStringArray(["--profile", ""])).error).is_not_empty()


func test_status_bands() -> void:
	assert_str(BalanceRunArgs.status(12.0, 12.0, 0.30)).is_equal("PASS")
	assert_str(BalanceRunArgs.status(8.4, 12.0, 0.30)).is_equal("PASS")
	assert_str(BalanceRunArgs.status(15.6, 12.0, 0.30)).is_equal("PASS")
	assert_str(BalanceRunArgs.status(7.0, 12.0, 0.30)).is_equal("WARN")
	assert_str(BalanceRunArgs.status(19.0, 12.0, 0.30)).is_equal("WARN")
	assert_str(BalanceRunArgs.status(4.0, 12.0, 0.30)).is_equal("FAIL")
	assert_str(BalanceRunArgs.status(20.0, 12.0, 0.30)).is_equal("FAIL")


func test_worst_status() -> void:
	assert_str(BalanceRunArgs.worst("PASS", "WARN")).is_equal("WARN")
	assert_str(BalanceRunArgs.worst("FAIL", "WARN")).is_equal("FAIL")
	assert_str(BalanceRunArgs.worst("PASS", "PASS")).is_equal("PASS")


func test_frame_and_policy_none() -> void:
	var a: BalanceRunArgs = BalanceRunArgs.parse(PackedStringArray(["--frame", "bulwark", "--policy", "none"]))
	assert_str(a.error).is_empty()
	assert_str(a.frame).is_equal("bulwark")
	assert_str(a.policy).is_equal("none")
	assert_str(BalanceRunArgs.parse(PackedStringArray()).frame).is_equal("vanguard")
	assert_str(BalanceRunArgs.parse(PackedStringArray(["--frame", "all"])).frame).is_equal("all")
	assert_str(BalanceRunArgs.parse(PackedStringArray(["--frame"])).error).is_not_empty()


func test_mode_flag() -> void:
	assert_str(BalanceRunArgs.parse(PackedStringArray()).mode).is_equal("timed")
	assert_str(BalanceRunArgs.parse(PackedStringArray(["--mode", "purge"])).mode).is_equal("purge")
	assert_str(BalanceRunArgs.parse(PackedStringArray(["--mode", "purge"])).error).is_empty()
	assert_str(BalanceRunArgs.parse(PackedStringArray(["--mode", "bogus"])).error).contains("--mode")
	assert_str(BalanceRunArgs.parse(PackedStringArray(["--mode"])).error).is_not_empty()
	assert_str(BalanceRunArgs.USAGE).contains("--mode timed|purge")


func test_target_rows_read_mode_and_default_to_timed() -> void:
	var with_col: CsvTable = CsvTable.parse("profile,mode,metric\nfresh,purge,m\nfresh,,m\n")
	assert_str(BalanceRunArgs.row_mode(with_col, 0)).is_equal("purge")
	assert_str(BalanceRunArgs.row_mode(with_col, 1)).is_equal("timed")
	var old: CsvTable = CsvTable.parse("profile,metric\nfresh,m\n")
	assert_str(BalanceRunArgs.row_mode(old, 0)).is_equal("timed")
	var real: CsvTable = CsvTable.load_file("res://data/targets.csv")
	assert_str(real.error).is_empty()
	var modes: PackedStringArray = PackedStringArray()
	for i: int in real.rows.size():
		modes.append(BalanceRunArgs.row_mode(real, i))
	assert_bool(modes.has("purge")).is_true()
	assert_bool(modes.has("timed")).is_true()


func test_purge_rows_are_info_only() -> void:
	assert_bool(BalanceRunArgs.info_only("fresh", "purge")).is_true()
	assert_bool(BalanceRunArgs.info_only("foundry_300", "timed")).is_true()
	assert_bool(BalanceRunArgs.info_only("fresh", "timed")).is_false()
