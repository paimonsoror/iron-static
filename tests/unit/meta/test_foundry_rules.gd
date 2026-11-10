class_name TestFoundryRules
extends GdUnitTestSuite
## FoundryRules (M3-06): cost, caps, multipliers, milestones, sums, Recommended.


func _defs() -> Array[FoundryDef]:
	return SimConfigLoader.load_foundry_defs()


func _def(id: String) -> FoundryDef:
	return FoundryRules.find_def(_defs(), id)


func _run_def(id: String) -> RunUpgradeDef:
	return FoundryRules.find_run_def(SimConfigLoader.load_default(1).upgrades, id)


func _row(
	kind: String, cost: int, to_milestone: int, affordable: bool, maxed: bool = false, capped: bool = false
) -> FoundryRowView:
	var r: FoundryRowView = FoundryRowView.new()
	r.kind = kind
	r.cost = BigNum.from_int(cost)
	r.levels_to_milestone = to_milestone
	r.affordable = affordable
	r.maxed = maxed
	r.capped = capped
	return r


func test_costs() -> void:
	var laser: FoundryDef = _def("laser_output")
	var got: Array[String] = []
	for lvl: int in 4:
		got.append(str(roundi(FoundryRules.cost(laser, lvl).to_float())))
	assert_array(got).is_equal(["20", "22", "25", "27"])
	assert_float(FoundryRules.cost(_def("nano_repair"), 0).to_float()).is_equal_approx(25.0, 1e-6)
	assert_float(FoundryRules.cost(_def("cycle_rate"), 0).to_float()).is_equal_approx(50.0, 1e-6)


func test_cost_stays_finite_at_cap() -> void:
	var c: BigNum = FoundryRules.cost(_def("laser_output"), 200)
	assert_bool(c.is_zero()).is_false()
	assert_float(c.log10()).is_equal_approx(20.0 * 0.0 + log(20.0 * pow(1.1, 200.0)) / log(10.0), 0.01)


func test_caps() -> void:
	assert_int(FoundryRules.level_cap(_def("cycle_rate"), _run_def("cycle_rate"))).is_equal(50)
	assert_int(FoundryRules.level_cap(_def("laser_output"), _run_def("laser_output"))).is_equal(200)


func test_multipliers_match_gdd() -> void:
	# GDD 05 s1.2 (FO-3): (1 + f*F) * 1.75^floor(F/25); hull f = 0.06 gives 4.4 / 12.3 / 65.7 / 1143.
	var hull: FoundryDef = _def("hull_integrity")
	assert_float(FoundryRules.multiplier(hull, 24)).is_equal_approx(2.44, 1e-9)  # no bump before F25
	assert_float(FoundryRules.multiplier(hull, 25)).is_equal_approx(4.375, 1e-9)
	assert_float(FoundryRules.multiplier(hull, 50)).is_equal_approx(12.25, 1e-9)
	assert_float(FoundryRules.multiplier(hull, 100)).is_equal_approx(65.66, 0.01)
	assert_float(FoundryRules.multiplier(hull, 200)).is_equal_approx(1143.5, 0.5)
	var nano: FoundryDef = _def("nano_repair")
	assert_float(FoundryRules.multiplier(nano, 25)).is_equal_approx(2.25 * 1.75, 1e-9)


func test_type_c_multiplier_is_start_delta() -> void:
	var cycle: FoundryDef = _def("cycle_rate")
	assert_float(FoundryRules.multiplier(cycle, 50, _run_def("cycle_rate"))).is_equal_approx(0.04 * 50.0, 1e-9)
	assert_float(FoundryRules.multiplier(cycle, 80, _run_def("cycle_rate"))).is_equal_approx(0.04 * 50.0, 1e-9)


func test_start_value_uses_the_resolver() -> void:
	var v: float = FoundryRules.start_value(_def("laser_output"), _run_def("laser_output"), 25)
	assert_float(v).is_equal_approx(10.0 * Curves.foundry_mult(25, 0.06), 1e-9)


func test_milestones() -> void:
	assert_int(FoundryRules.MILESTONE_STEP).is_equal(Curves.MILESTONE_FOUNDRY_STEP)
	assert_int(FoundryRules.levels_to_milestone(24)).is_equal(1)
	assert_int(FoundryRules.levels_to_milestone(25)).is_equal(25)
	assert_int(FoundryRules.levels_to_milestone(0)).is_equal(25)
	assert_int(FoundryRules.next_milestone(25)).is_equal(50)
	assert_int(FoundryRules.levels_to_milestone(24, _def("cycle_rate"))).is_equal(-1)


func test_wave_cap_formula() -> void:
	assert_int(FoundryRules.wave_cap(0)).is_equal(3)  # cap_min floor
	assert_int(FoundryRules.wave_cap(5)).is_equal(3)
	assert_int(FoundryRules.wave_cap(6)).is_equal(3)
	assert_int(FoundryRules.wave_cap(10)).is_equal(6)
	assert_int(FoundryRules.wave_cap(15)).is_equal(9)
	assert_int(FoundryRules.wave_cap(35)).is_equal(21)
	assert_int(FoundryRules.wave_cap(100)).is_equal(60)
	assert_int(FoundryRules.wave_cap(-4)).is_equal(3)


func test_level_limit_never_exceeds_the_row_cap() -> void:
	var cycle: FoundryDef = _def("cycle_rate")  # row cap 50
	assert_int(FoundryRules.level_limit(cycle, _run_def("cycle_rate"), 0)).is_equal(3)
	assert_int(FoundryRules.level_limit(cycle, _run_def("cycle_rate"), 60)).is_equal(36)
	assert_int(FoundryRules.level_limit(cycle, _run_def("cycle_rate"), 500)).is_equal(50)


func test_wave_for_level_is_the_smallest_best_wave() -> void:
	assert_int(FoundryRules.wave_for_level(3)).is_equal(0)
	for target: int in range(4, 120):
		var w: int = FoundryRules.wave_for_level(target)
		assert_int(FoundryRules.wave_cap(w)).is_greater_equal(target)
		assert_int(FoundryRules.wave_cap(w - 1)).is_less(target)
	assert_int(FoundryRules.wave_for_level(4)).is_equal(7)
	assert_int(FoundryRules.wave_for_level(10)).is_equal(17)


func test_total_cost_and_max_affordable() -> void:
	var laser: FoundryDef = _def("laser_output")
	# 20+22+25+27+30+33+36+39+43 = 275 (the task text says 278; the ceil sums give 275).
	assert_float(FoundryRules.total_cost(laser, 0, 9).to_float()).is_equal_approx(275.0, 1e-6)
	assert_float(FoundryRules.total_cost(laser, 0, 10).to_float()).is_equal_approx(323.0, 1e-6)
	assert_int(FoundryRules.max_affordable(laser, 0, BigNum.from_int(300), 100)).is_equal(9)
	assert_int(FoundryRules.max_affordable(laser, 0, BigNum.from_int(300), 4)).is_equal(4)
	assert_int(FoundryRules.max_affordable(laser, 0, BigNum.from_int(19), 100)).is_equal(0)


func test_total_cost_beyond_the_exact_cap_uses_the_closed_form() -> void:
	var laser: FoundryDef = _def("laser_output")
	var exact: BigNum = FoundryRules.total_cost(laser, 0, 200)
	var closed: float = 20.0 * (pow(1.1, 200.0) - 1.0) / 0.1
	assert_float(exact.to_float()).is_equal_approx(closed, closed * 0.001)
	var big: BigNum = FoundryRules.total_cost(laser, 0, 320)
	assert_bool(big.gt(exact)).is_true()


func test_recommended_prefers_cheap_milestone_row() -> void:
	var rows: Array[FoundryRowView] = [_row("D", 50, 2, true), _row("D", 30, 9, true), _row("D", 40, 3, true)]
	assert_int(FoundryRules.recommended(rows)).is_equal(2)
	var near_cheap: Array[FoundryRowView] = [_row("D", 50, 1, false), _row("D", 20, 3, true)]
	assert_int(FoundryRules.recommended(near_cheap)).is_equal(1)


func test_recommended_falls_back_to_cheapest_affordable_then_none() -> void:
	var rows: Array[FoundryRowView] = [_row("D", 50, 9, true), _row("C", 30, -1, true), _row("D", 10, 8, false)]
	assert_int(FoundryRules.recommended(rows)).is_equal(1)
	var none: Array[FoundryRowView] = [_row("D", 50, 9, false), _row("C", 30, -1, false)]
	assert_int(FoundryRules.recommended(none)).is_equal(-1)
	var maxed: Array[FoundryRowView] = [_row("D", 0, -1, false, true)]
	assert_int(FoundryRules.recommended(maxed)).is_equal(-1)


func test_recommended_skips_capped_rows() -> void:
	var rows: Array[FoundryRowView] = [
		_row("D", 5, 1, false, false, true), _row("D", 40, 20, true), _row("D", 10, 2, false, false, true)
	]
	assert_int(FoundryRules.recommended(rows)).is_equal(1)
	var all_capped: Array[FoundryRowView] = [_row("D", 5, 1, false, false, true)]
	assert_int(FoundryRules.recommended(all_capped)).is_equal(-1)
