class_name TestJourneyPacing
extends GdUnitTestSuite
## Journey pacing instrument math (R1-01): the no-new-best streak, unspent Data against income, target rows.


func _rec(dep: int, new_best: bool, streak: int, income: float, unspent: float) -> Dictionary:
	return {
		"dep": dep,
		"new_best": new_best,
		"no_best_streak": streak,
		"data": income,
		"data_unspent": unspent,
		"best_after": 10 + dep,
		"cum_min_1x": 10.0 * float(dep),
	}


func test_streak_resets_on_a_new_best_and_counts_otherwise() -> void:
	var s: int = 0
	var seen: Array[int] = []
	for new_best: bool in [true, false, false, true, false]:
		s = JourneyPacing.next_streak(s, new_best)
		seen.append(s)
	assert_array(seen).is_equal([0, 1, 2, 0, 1])


func test_max_streak_only_looks_at_the_window() -> void:
	var records: Array[Dictionary] = []
	for i: int in 40:
		records.append(_rec(i + 1, false, 0 if i < 30 else i, 10.0, 0.0))
	records[5]["no_best_streak"] = 3
	assert_int(JourneyPacing.max_streak(records)).is_equal(3)
	assert_int(JourneyPacing.max_streak(records, 40)).is_equal(39)


func test_unspent_ratio_edges() -> void:
	assert_float(JourneyPacing.unspent_ratio(0.0, 0.0)).is_equal(0.0)
	assert_float(JourneyPacing.unspent_ratio(30.0, 20.0)).is_equal_approx(1.5, 1e-9)
	assert_bool(is_inf(JourneyPacing.unspent_ratio(5.0, 0.0))).is_true()


func test_max_unspent_picks_the_worst_deployment() -> void:
	var records: Array[Dictionary] = [
		_rec(1, true, 0, 20.0, 10.0), _rec(2, true, 0, 10.0, 25.0), _rec(3, false, 1, 50.0, 5.0)
	]
	var worst: Dictionary = JourneyPacing.max_unspent(records)
	assert_int(worst["dep"]).is_equal(2)
	assert_float(worst["ratio"]).is_equal_approx(2.5, 1e-9)


func test_metrics_and_target_lines() -> void:
	var records: Array[Dictionary] = []
	for i: int in 4:
		records.append(_rec(i + 1, true, 0, 10.0, 5.0))
	var m: Dictionary = JourneyPacing.metrics(records)
	assert_float(m[JourneyPacing.M_STREAK]).is_equal(0.0)
	assert_float(m[JourneyPacing.M_UNSPENT]).is_equal_approx(0.5, 1e-9)
	assert_float(m[JourneyPacing.M_BEST_3]).is_equal(13.0)
	assert_bool(m.has(JourneyPacing.M_BEST_DAY1)).is_false()  # 40 min of 1x = 20 min of 2x: not reached
	var table: CsvTable = CsvTable.load_file("res://data/targets.csv")
	var lines: PackedStringArray = JourneyPacing.target_lines(table, m)
	assert_int(lines.size()).is_equal(4)
	var text: String = "\n".join(lines)
	assert_str(text).contains("journey_max_no_best_streak_30 measured=0.00 target<=4.00 PASS")
	assert_str(text).contains("journey_best_after_3 measured=13.00 target~22.50 FAIL")
	assert_str(text).contains("journey_best_day1 SKIP")


func test_upper_bound_status() -> void:
	assert_str(JourneyPacing.status(JourneyPacing.M_STREAK, 4.0, 4.0, 0.0)).is_equal("PASS")
	assert_str(JourneyPacing.status(JourneyPacing.M_STREAK, 5.0, 4.0, 0.0)).is_equal("FAIL")
	assert_str(JourneyPacing.status(JourneyPacing.M_BEST_3, 24.0, 22.5, 0.111)).is_equal("PASS")


func test_journey_records_carry_the_pacing_columns() -> void:
	var args: JourneyArgs = JourneyArgs.parse(PackedStringArray(["--deployments", "3", "--waves", "6", "--seed", "3"]))
	var records: Array[Dictionary] = JourneySim.new(args, JourneyOverrides.new()).run()
	assert_int(records.size()).is_equal(3)
	assert_int(records[0]["no_best_streak"]).is_equal(0)  # first deployment sets the first best
	for r: Dictionary in records:
		var unspent: float = r["data_unspent"]
		var left: float = r["left"]
		assert_float(unspent).is_equal_approx(left, 1e-9)
