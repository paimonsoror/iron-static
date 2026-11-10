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


func test_buy_stops_at_the_wave_cap() -> void:
	var s: FoundryService = _service()
	var p: PlayerProfile = _capped_profile(10)  # cap 6
	assert_int(s.buy(p, "laser_output", 50)).is_equal(6)
	assert_int(p.foundry_level("laser_output")).is_equal(6)
	assert_int(s.buy(p, "laser_output", 1)).is_equal(0)
	p.best_wave["1"] = 12  # cap 7
	assert_int(s.buy(p, "laser_output", 5)).is_equal(1)


func test_cap_floor_is_three_levels_without_a_best_wave() -> void:
	var s: FoundryService = _service()
	var p: PlayerProfile = _capped_profile(0)
	assert_int(s.buy(p, "laser_output", 10)).is_equal(3)
	assert_int(s.buy(p, "hull_integrity", 10)).is_equal(3)


func test_capped_row_view_and_hint() -> void:
	var s: FoundryService = _service()
	var p: PlayerProfile = _capped_profile(10)
	p.set_foundry_level("laser_output", 6)
	var r: FoundryRowView = s.rows(p)[0]
	assert_bool(r.capped).is_true()
	assert_bool(r.maxed).is_false()
	assert_bool(r.affordable).is_false()
	assert_int(r.limit).is_equal(6)
	assert_int(r.next_wave).is_equal(12)  # floor(0.6 * 12) = 7
	assert_bool(s.rows(_capped_profile(10))[0].capped).is_false()
	assert_int(s.affordable_count(p)).is_equal(3)  # the capped row is not counted


func test_grandfathered_levels_are_kept() -> void:
	var s: FoundryService = _service()
	var p: PlayerProfile = _capped_profile(10)  # cap 6
	p.set_foundry_level("laser_output", 30)
	var r: FoundryRowView = s.rows(p)[0]
	assert_int(r.level).is_equal(30)
	assert_bool(r.capped).is_true()
	assert_int(r.next_wave).is_equal(52)  # 31 levels need floor(0.6 w) >= 31
	assert_int(s.buy(p, "laser_output", 5)).is_equal(0)
	assert_int(p.foundry_level("laser_output")).is_equal(30)
	p.best_wave["1"] = 52
	assert_int(s.buy(p, "laser_output", 5)).is_equal(1)


func test_recommended_skips_a_capped_row() -> void:
	var p: PlayerProfile = _capped_profile(10, 500)
	p.set_foundry_level("nano_repair", 6)  # capped; would be the cheapest
	p.set_foundry_level("laser_output", 2)
	var rows: Array[FoundryRowView] = _service().rows(p)
	assert_bool(rows[3].recommended).is_false()
	var flagged: int = 0
	for r: FoundryRowView in rows:
		flagged += 1 if r.recommended else 0
	assert_int(flagged).is_equal(1)


func test_wave_cap_can_be_lifted_for_tools() -> void:
	var s: FoundryService = _service()
	s.wave_cap_enabled = false
	assert_int(s.buy(_capped_profile(0), "laser_output", 10)).is_equal(10)
