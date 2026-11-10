class_name TestFoundryRules
extends GdUnitTestSuite
## FoundryRules (M3-06): cost, caps, multipliers, milestones, sums, Recommended.


func _defs() -> Array[FoundryDef]:
	return SimConfigLoader.load_foundry_defs()


func _def(id: String) -> FoundryDef:
	return FoundryRules.find_def(_defs(), id)


func _run_def(id: String) -> RunUpgradeDef:
	return FoundryRules.find_run_def(SimConfigLoader.load_default(1).upgrades, id)


## The tuning with the FO-3 era soft cap pinned (x3 flat, k 0.6); shipped values: `test_shipped_soft_cap_rows`.
func _t() -> SimTuning:
	var t: SimTuning = SimConfigLoader.load_tuning()
	t.foundry_over_cap_mult = 3.0
	t.foundry_over_cap_growth = 1.0
	t.foundry_cap_k = 0.6
	return t


func _row(
	kind: String, cost: int, to_milestone: int, affordable: bool, maxed: bool = false, over_limit: bool = false
) -> FoundryRowView:
	var r: FoundryRowView = FoundryRowView.new()
	r.kind = kind
	r.cost = BigNum.from_int(cost)
	r.levels_to_milestone = to_milestone
	r.affordable = affordable
	r.maxed = maxed
	r.over_limit = over_limit
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
	var t: SimTuning = _t()
	assert_float(FoundryRules.multiplier(hull, 24, null, t)).is_equal_approx(2.44, 1e-9)  # no bump before F25
	assert_float(FoundryRules.multiplier(hull, 25, null, t)).is_equal_approx(4.375, 1e-9)
	assert_float(FoundryRules.multiplier(hull, 50, null, t)).is_equal_approx(12.25, 1e-9)
	assert_float(FoundryRules.multiplier(hull, 100, null, t)).is_equal_approx(65.66, 0.01)
	assert_float(FoundryRules.multiplier(hull, 200, null, t)).is_equal_approx(1143.5, 0.5)
	var nano: FoundryDef = _def("nano_repair")
	assert_float(FoundryRules.multiplier(nano, 25, null, t)).is_equal_approx(2.25 * 1.75, 1e-9)


func test_type_c_multiplier_is_start_delta() -> void:
	var cycle: FoundryDef = _def("cycle_rate")
	assert_float(FoundryRules.multiplier(cycle, 50, _run_def("cycle_rate"))).is_equal_approx(0.04 * 50.0, 1e-9)
	assert_float(FoundryRules.multiplier(cycle, 80, _run_def("cycle_rate"))).is_equal_approx(0.04 * 50.0, 1e-9)


func test_start_value_uses_the_resolver() -> void:
	var v: float = FoundryRules.start_value(_def("laser_output"), _run_def("laser_output"), 25, _t())
	assert_float(v).is_equal_approx(10.0 * Curves.foundry_mult(25, 0.06), 1e-9)


func test_milestones_are_data() -> void:
	var t: SimTuning = _t()
	assert_int(Curves.foundry_step(t)).is_equal(25)
	assert_float(Curves.foundry_milestone_mult(t)).is_equal(1.75)
	assert_int(FoundryRules.levels_to_milestone(24, null, t)).is_equal(1)
	assert_int(FoundryRules.levels_to_milestone(25, null, t)).is_equal(25)
	assert_int(FoundryRules.levels_to_milestone(0, null, t)).is_equal(25)
	assert_int(FoundryRules.next_milestone(25, t)).is_equal(50)
	assert_int(FoundryRules.levels_to_milestone(24, _def("cycle_rate"), t)).is_equal(-1)
	# A different data row moves the milestone (no code constant left).
	t.foundry_milestone_step = 10
	t.foundry_milestone_mult = 2.0
	assert_int(FoundryRules.levels_to_milestone(24, null, t)).is_equal(6)
	assert_float(FoundryRules.multiplier(_def("hull_integrity"), 10, null, t)).is_equal_approx((1.0 + 0.6) * 2.0, 1e-9)


func test_wave_cap_formula() -> void:
	var t: SimTuning = _t()
	assert_int(t.foundry_cap_min).is_equal(6)  # the R1-02 tune; the checks below use the original floor of 3
	t.foundry_cap_min = 3
	assert_int(FoundryRules.wave_cap(0, t)).is_equal(3)  # cap_min floor
	assert_int(FoundryRules.wave_cap(5, t)).is_equal(3)
	assert_int(FoundryRules.wave_cap(6, t)).is_equal(3)
	assert_int(FoundryRules.wave_cap(10, t)).is_equal(6)
	assert_int(FoundryRules.wave_cap(15, t)).is_equal(9)
	assert_int(FoundryRules.wave_cap(35, t)).is_equal(21)
	assert_int(FoundryRules.wave_cap(100, t)).is_equal(60)
	assert_int(FoundryRules.wave_cap(-4, t)).is_equal(3)
	t.foundry_cap_k = 0.5
	t.foundry_cap_min = 5
	assert_int(FoundryRules.wave_cap(10, t)).is_equal(5)
	assert_int(FoundryRules.wave_cap(40, t)).is_equal(20)


func test_wave_for_level_is_the_smallest_best_wave() -> void:
	var t: SimTuning = _t()
	t.foundry_cap_min = 3
	assert_int(FoundryRules.wave_for_level(3, t)).is_equal(0)
	for target: int in range(4, 120):
		var w: int = FoundryRules.wave_for_level(target, t)
		assert_int(FoundryRules.wave_cap(w, t)).is_greater_equal(target)
		assert_int(FoundryRules.wave_cap(w - 1, t)).is_less(target)
	assert_int(FoundryRules.wave_for_level(4, t)).is_equal(7)
	assert_int(FoundryRules.wave_for_level(10, t)).is_equal(17)


func test_soft_cap_step_cost_is_flat_over_the_limit() -> void:
	var laser: FoundryDef = _def("laser_output")
	var t: SimTuning = _t()
	assert_float(t.foundry_over_cap_mult).is_equal(3.0)
	# limit 3: levels 0, 1, 2 at the normal price, level 3 and above x3 (never forbidden).
	assert_float(FoundryRules.step_cost(laser, 2, 3, t).to_float()).is_equal_approx(25.0, 1e-6)
	assert_float(FoundryRules.step_cost(laser, 3, 3, t).to_float()).is_equal_approx(3.0 * 27.0, 1e-6)
	assert_float(FoundryRules.step_cost(laser, 9, 3, t).to_float()).is_equal_approx(3.0 * 48.0, 1.0)
	t.foundry_over_cap_mult = 2.5
	assert_float(FoundryRules.step_cost(laser, 3, 3, t).to_float()).is_equal_approx(floorf(2.5 * 27.0), 1e-6)


func test_compounding_over_cap_growth() -> void:
	var laser: FoundryDef = _def("laser_output")
	var t: SimTuning = _t()
	assert_float(t.foundry_over_cap_growth).is_greater_equal(1.0)
	t.foundry_over_cap_mult = 3.0
	t.foundry_over_cap_growth = 1.5
	t.foundry_cap_min = 3
	# limit 3: level 3 costs x3, level 4 x4.5, level 5 x6.75 of the row cost.
	assert_float(FoundryRules.over_mult_at(3, 3, t)).is_equal_approx(3.0, 1e-9)
	assert_float(FoundryRules.over_mult_at(5, 3, t)).is_equal_approx(6.75, 1e-9)
	assert_float(FoundryRules.step_cost(laser, 5, 3, t).to_float()).is_equal_approx(
		floorf(FoundryRules.cost(laser, 5).to_float() * 6.75), 1.0
	)
	var exact: float = 0.0
	for i: int in 330:
		exact += FoundryRules.step_cost(laser, i, 3, t).to_float()
	var big: float = FoundryRules.total_cost(laser, 0, 330, 3, t).to_float()
	assert_float(big).is_equal_approx(exact, exact * 0.01)


func test_total_cost_and_max_affordable() -> void:
	var laser: FoundryDef = _def("laser_output")
	var t: SimTuning = _t()
	var open: int = FoundryRules.NO_LIMIT
	# 20+22+25+27+30+33+36+39+43 = 275 (the task text says 278; the ceil sums give 275).
	assert_float(FoundryRules.total_cost(laser, 0, 9, open, t).to_float()).is_equal_approx(275.0, 1e-6)
	assert_float(FoundryRules.total_cost(laser, 0, 10, open, t).to_float()).is_equal_approx(323.0, 1e-6)
	assert_int(FoundryRules.max_affordable(laser, 0, BigNum.from_int(300), 100, open, t)).is_equal(9)
	assert_int(FoundryRules.max_affordable(laser, 0, BigNum.from_int(300), 4, open, t)).is_equal(4)
	assert_int(FoundryRules.max_affordable(laser, 0, BigNum.from_int(19), 100, open, t)).is_equal(0)


func test_total_cost_and_max_affordable_with_the_soft_cap() -> void:
	var laser: FoundryDef = _def("laser_output")
	var t: SimTuning = _t()
	# limit 3: 20 + 22 + 25 at the normal price, then 3 * 27 + 3 * 30 for levels 3 and 4.
	assert_float(FoundryRules.total_cost(laser, 0, 5, 3, t).to_float()).is_equal_approx(67.0 + 81.0 + 90.0, 1e-6)
	assert_int(FoundryRules.max_affordable(laser, 0, BigNum.from_int(67), 100, 3, t)).is_equal(3)
	assert_int(FoundryRules.max_affordable(laser, 0, BigNum.from_int(67 + 81), 100, 3, t)).is_equal(4)
	assert_int(FoundryRules.max_affordable(laser, 0, BigNum.from_int(67 + 80), 100, 3, t)).is_equal(3)


func test_total_cost_beyond_the_exact_cap_uses_the_closed_form() -> void:
	var laser: FoundryDef = _def("laser_output")
	var t: SimTuning = _t()
	var open: int = FoundryRules.NO_LIMIT
	var exact: BigNum = FoundryRules.total_cost(laser, 0, 200, open, t)
	var closed: float = 20.0 * (pow(1.1, 200.0) - 1.0) / 0.1
	assert_float(exact.to_float()).is_equal_approx(closed, closed * 0.001)
	var big: BigNum = FoundryRules.total_cost(laser, 0, 320, open, t)
	assert_bool(big.gt(exact)).is_true()
	# With a limit inside the closed-form segment the over part is the geometric sum times the multiplier.
	var soft: BigNum = FoundryRules.total_cost(laser, 0, 320, 310, t)
	assert_bool(soft.gt(big)).is_true()


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


func test_recommended_prefers_rows_below_the_limit() -> void:
	# A cheaper row near a milestone but over the limit (x3 price) loses to a below-limit row, even a plain one.
	var rows: Array[FoundryRowView] = [
		_row("D", 5, 1, true, false, true), _row("D", 40, 20, true), _row("D", 10, 2, true, false, true)
	]
	assert_int(FoundryRules.recommended(rows)).is_equal(1)
	# Nothing below the limit qualifies: the over-limit rows are recommended with the same rules.
	var all_over: Array[FoundryRowView] = [_row("D", 50, 1, true, false, true), _row("D", 20, 2, true, false, true)]
	assert_int(FoundryRules.recommended(all_over)).is_equal(1)
	var unaffordable_over: Array[FoundryRowView] = [_row("D", 50, 9, false, false, true)]
	assert_int(FoundryRules.recommended(unaffordable_over)).is_equal(-1)


func test_shipped_soft_cap_rows() -> void:
	var t: SimTuning = SimConfigLoader.load_tuning()  # the R1-02 tune
	assert_int(t.foundry_cap_min).is_equal(6)
	assert_float(t.foundry_cap_k).is_equal(0.7)
	assert_float(t.foundry_over_cap_mult).is_equal(2.0)
	assert_float(t.foundry_over_cap_growth).is_equal(1.0)  # flat: compounding was not needed


func test_fallback_milestones_equal_the_data_rows() -> void:
	# Curves keeps FALLBACK_* only for callers with no tuning; they must not drift from data/sim_constants.csv.
	var t: SimTuning = _t()
	assert_int(Curves.FALLBACK_RUN_STEP).is_equal(t.run_milestone_step)
	assert_float(Curves.FALLBACK_RUN_MULT).is_equal(t.run_milestone_mult)
	assert_int(Curves.FALLBACK_FOUNDRY_STEP).is_equal(t.foundry_milestone_step)
	assert_float(Curves.FALLBACK_FOUNDRY_MULT).is_equal(t.foundry_milestone_mult)
