class_name TestFoundryService
extends GdUnitTestSuite
## FoundryService (M3-06): rows, buying, affordability, Power Rating preview.


func _service() -> FoundryService:
	return FoundryService.new(SimConfigLoader.load_foundry_defs(), SimConfigLoader.load_default(1).upgrades)


func _profile(data: int) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.fresh(0, "test")
	p.data = BigNum.from_int(data)
	p.best_wave["1"] = 100  # wave cap 60: out of the way unless a test lowers it
	return p


func test_rows_order_and_first_costs() -> void:
	var rows: Array[FoundryRowView] = _service().rows(_profile(0))
	var ids: Array[String] = []
	for r: FoundryRowView in rows:
		ids.append(r.id)
	assert_array(ids).is_equal(["laser_output", "cycle_rate", "hull_integrity", "nano_repair"])
	assert_float(rows[0].cost.to_float()).is_equal_approx(20.0, 1e-6)
	assert_float(rows[1].cost.to_float()).is_equal_approx(50.0, 1e-6)
	assert_int(rows[1].cap).is_equal(50)
	assert_int(rows[0].levels_to_milestone).is_equal(25)
	assert_int(rows[1].levels_to_milestone).is_equal(-1)
	assert_int(rows.filter(func(r: FoundryRowView) -> bool: return r.recommended).size()).is_equal(0)


func test_row_values_and_delta() -> void:
	var p: PlayerProfile = _profile(0)
	p.set_foundry_level("laser_output", 24)
	var r: FoundryRowView = _service().rows(p)[0]
	assert_float(r.start_now).is_equal_approx(10.0 * Curves.foundry_mult(24, 0.06), 1e-9)
	assert_float(r.start_next).is_equal_approx(10.0 * Curves.foundry_mult(25, 0.06), 1e-9)
	assert_float(r.delta).is_equal_approx(r.start_next - r.start_now, 1e-9)
	assert_int(r.levels_to_milestone).is_equal(1)
	assert_float(r.mult_next).is_greater(r.mult_now)


func test_buy_partial_then_more() -> void:
	var s: FoundryService = _service()
	var p: PlayerProfile = _profile(300)
	assert_int(s.buy(p, "laser_output", 100)).is_equal(9)
	assert_float(p.data.to_float()).is_equal_approx(25.0, 1e-6)
	assert_int(p.foundry_level("laser_output")).is_equal(9)
	assert_int(s.buy(p, "laser_output", 1)).is_equal(0)
	p.data = p.data.add(BigNum.from_int(23))
	assert_int(s.buy(p, "laser_output", 1)).is_equal(1)
	assert_float(p.data.to_float()).is_less(1e-6)
	assert_int(p.foundry_level("laser_output")).is_equal(10)


func test_buy_rejections() -> void:
	var s: FoundryService = _service()
	var p: PlayerProfile = _profile(1000000)
	assert_int(s.buy(p, "laser_output", 0)).is_equal(0)
	assert_int(s.buy(p, "laser_output", -3)).is_equal(0)
	assert_int(s.buy(p, "no_such_row", 1)).is_equal(0)
	assert_float(p.data.to_float()).is_equal_approx(1000000.0, 1e-6)
	p.set_foundry_level("cycle_rate", 50)
	assert_int(s.buy(p, "cycle_rate", 5)).is_equal(0)
	assert_int(p.foundry_level("cycle_rate")).is_equal(50)
	assert_bool(s.rows(p)[1].maxed).is_true()


func test_buy_never_exceeds_the_cap() -> void:
	var s: FoundryService = _service()
	var p: PlayerProfile = _profile(1000000)
	p.set_foundry_level("cycle_rate", 48)
	assert_int(s.buy(p, "cycle_rate", 10)).is_equal(2)
	assert_int(p.foundry_level("cycle_rate")).is_equal(50)


func test_affordable_count_and_recommended_flag() -> void:
	var s: FoundryService = _service()
	assert_int(s.affordable_count(_profile(19))).is_equal(0)
	assert_int(s.affordable_count(_profile(20))).is_equal(2)
	assert_int(s.affordable_count(_profile(50))).is_equal(4)
	var rows: Array[FoundryRowView] = s.rows(_profile(25))
	assert_bool(rows[0].recommended).is_true()
	var flagged: int = 0
	for r: FoundryRowView in rows:
		flagged += 1 if r.recommended else 0
	assert_int(flagged).is_equal(1)


func test_recommended_prefers_row_near_a_milestone() -> void:
	var p: PlayerProfile = _profile(0)
	p.set_foundry_level("nano_repair", 22)
	var rows: Array[FoundryRowView] = _service().rows(p)
	assert_bool(rows[3].recommended).is_true()


func test_afford_in_minutes() -> void:
	var s: FoundryService = _service()
	var p: PlayerProfile = _profile(10)
	assert_float(s.rows(p)[0].afford_in_minutes).is_equal(-1.0)
	p.farm_rate_1x = 5.0
	assert_float(s.rows(p)[0].afford_in_minutes).is_equal_approx(2.0, 1e-9)
	p.data = BigNum.from_int(20)
	assert_float(s.rows(p)[0].afford_in_minutes).is_equal(0.0)


func test_power_rating_preview_rises_with_a_level() -> void:
	var s: FoundryService = _service()
	var pr: Vector2 = s.power_rating_preview(_profile(0), "laser_output")
	assert_float(pr.x).is_greater(31.0)
	assert_float(pr.x).is_less(33.0)
	assert_float(pr.y).is_greater(pr.x)
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	var base: float = PowerRating.power_rating(StatBlock.from_resolver(cfg.upgrades, PackedInt32Array()))
	assert_float(pr.x).is_equal_approx(base, 1e-4)  # Vector2 holds float32: ~1e-6 relative precision


func _capped_profile(best: int, data: int = 1000000) -> PlayerProfile:
	var p: PlayerProfile = _profile(data)
	p.best_wave["1"] = best
	return p


func _cost_of(s: FoundryService, id: String, level: int, count: int, best: int) -> float:
	var def: FoundryDef = FoundryRules.find_def(s.defs, id)
	var limit: int = FoundryRules.wave_cap(best, s.tuning)
	return FoundryRules.total_cost(def, level, count, limit, s.tuning).to_float()


func test_levels_over_the_wave_cap_are_bought_at_the_multiplied_price() -> void:
	var s: FoundryService = _service()
	var p: PlayerProfile = _capped_profile(10)  # soft cap 6
	var before: float = p.data.to_float()
	assert_int(s.buy(p, "laser_output", 50)).is_equal(50)  # never forbidden
	assert_int(p.foundry_level("laser_output")).is_equal(50)
	assert_float(before - p.data.to_float()).is_equal_approx(_cost_of(s, "laser_output", 0, 50, 10), 0.5)
	assert_float(_cost_of(s, "laser_output", 0, 50, 10)).is_greater(_cost_of(s, "laser_output", 0, 50, 100))


func test_the_first_over_cap_level_costs_three_times_the_row_cost() -> void:
	var s: FoundryService = _service()
	var p: PlayerProfile = _capped_profile(10)  # soft cap 6
	p.set_foundry_level("laser_output", 6)
	var def: FoundryDef = FoundryRules.find_def(s.defs, "laser_output")
	var normal: float = FoundryRules.cost(def, 6).to_float()
	p.data = BigNum.from_float(3.0 * normal - 1.0)
	assert_int(s.buy(p, "laser_output", 1)).is_equal(0)  # one data short of x3
	p.data = BigNum.from_float(3.0 * normal)
	assert_int(s.buy(p, "laser_output", 1)).is_equal(1)
	assert_float(p.data.to_float()).is_equal_approx(0.0, 0.5)


func test_cap_floor_is_three_levels_at_the_normal_price_without_a_best_wave() -> void:
	var s: FoundryService = _service()
	var p: PlayerProfile = _capped_profile(0, 67)  # 20 + 22 + 25 = the first three laser levels
	assert_int(s.buy(p, "laser_output", 10)).is_equal(3)
	assert_float(p.data.to_float()).is_equal_approx(0.0, 0.5)
	assert_int(s.buy(p, "hull_integrity", 10)).is_equal(0)


func test_over_limit_row_view_and_hint() -> void:
	var s: FoundryService = _service()
	var p: PlayerProfile = _capped_profile(10)
	p.set_foundry_level("laser_output", 6)
	var r: FoundryRowView = s.rows(p)[0]
	assert_bool(r.over_limit).is_true()
	assert_bool(r.maxed).is_false()
	assert_bool(r.affordable).is_true()  # still buyable, never locked
	assert_int(r.limit).is_equal(6)
	assert_int(r.room_below_limit).is_equal(0)
	assert_float(r.over_mult).is_equal(3.0)
	assert_float(r.cost.to_float()).is_equal_approx(3.0 * r.base_cost.to_float(), 1.0)
	assert_int(r.next_wave).is_equal(12)  # floor(0.6 * 12) = 7
	var below: FoundryRowView = s.rows(_capped_profile(10))[0]
	assert_bool(below.over_limit).is_false()
	assert_int(below.room_below_limit).is_equal(6)
	assert_int(s.affordable_count(p)).is_equal(3)  # the over-limit row is not counted in the badge


func test_grandfathered_levels_are_kept_and_cost_more() -> void:
	var s: FoundryService = _service()
	var p: PlayerProfile = _capped_profile(10)  # soft cap 6
	p.set_foundry_level("laser_output", 30)
	var r: FoundryRowView = s.rows(p)[0]
	assert_int(r.level).is_equal(30)
	assert_bool(r.over_limit).is_true()
	assert_int(r.next_wave).is_equal(52)  # 31 levels need floor(0.6 w) >= 31
	assert_int(s.buy(p, "laser_output", 5)).is_equal(5)
	assert_int(p.foundry_level("laser_output")).is_equal(35)
	p.best_wave["1"] = 100
	var back: FoundryRowView = s.rows(p)[0]
	assert_bool(back.over_limit).is_false()
	assert_float(back.cost.to_float()).is_equal_approx(back.base_cost.to_float(), 1e-9)


func test_recommended_prefers_a_row_below_the_limit() -> void:
	var p: PlayerProfile = _capped_profile(10, 500)
	p.set_foundry_level("nano_repair", 6)  # over the limit; would be the cheapest
	p.set_foundry_level("laser_output", 2)
	var rows: Array[FoundryRowView] = _service().rows(p)
	assert_bool(rows[3].recommended).is_false()
	var flagged: int = 0
	for r: FoundryRowView in rows:
		flagged += 1 if r.recommended else 0
	assert_int(flagged).is_equal(1)


func test_recommended_falls_back_to_an_over_limit_row_when_all_are_over() -> void:
	var p: PlayerProfile = _capped_profile(0, 100000)
	for id: String in ["laser_output", "cycle_rate", "hull_integrity", "nano_repair"]:
		p.set_foundry_level(id, 3)
	var flagged: int = 0
	for r: FoundryRowView in _service().rows(p):
		flagged += 1 if r.recommended else 0
	assert_int(flagged).is_equal(1)


func test_the_wave_cap_can_be_lifted_for_tools() -> void:
	var s: FoundryService = _service()
	s.wave_cap_enabled = false
	var p: PlayerProfile = _capped_profile(0)
	assert_int(s.buy(p, "laser_output", 10)).is_equal(10)
	var def: FoundryDef = FoundryRules.find_def(s.defs, "laser_output")
	assert_float(1000000.0 - p.data.to_float()).is_equal_approx(
		FoundryRules.total_cost(def, 0, 10, FoundryRules.NO_LIMIT, s.tuning).to_float(), 0.5
	)


func test_a_tuned_multiplier_changes_the_price() -> void:
	var s: FoundryService = _service()
	s.tuning.foundry_over_cap_mult = 5.0
	var p: PlayerProfile = _capped_profile(0)
	p.set_foundry_level("laser_output", 3)
	var r: FoundryRowView = s.rows(p)[0]
	assert_float(r.cost.to_float()).is_equal_approx(5.0 * r.base_cost.to_float(), 1.0)
