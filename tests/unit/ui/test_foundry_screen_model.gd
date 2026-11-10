class_name TestFoundryScreenModel
extends GdUnitTestSuite
## FoundryRowModel (M3-16): texts from a FoundryRowView.


func _service() -> FoundryService:
	return FoundryService.new(SimConfigLoader.load_foundry_defs(), SimConfigLoader.load_default(1).upgrades)


func _profile(data: int) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.fresh(0, "test")
	p.data = BigNum.from_int(data)
	p.runs_total = 1
	return p


func _model(p: PlayerProfile, i: int) -> FoundryRowModel:
	var views: Array[FoundryRowView] = _service().rows(p)
	return FoundryRowModel.from_view(views[i], i)


func test_laser_f0_to_f1_texts() -> void:
	var m: FoundryRowModel = _model(_profile(0), 0)
	assert_str(m.name_text).is_equal("LASER OUTPUT")
	assert_str(m.level_text).is_equal("F0")
	assert_str(m.value_text).is_equal("x1.00 -> x1.06")
	assert_bool(m.delta_text.begins_with("+")).is_true()
	assert_str(m.cost_text).is_equal("20")
	assert_str(m.milestone_text).is_equal("MILESTONE F25  x1.75")
	assert_bool(m.affordable).is_false()
	assert_str(m.value_line()).is_equal(m.value_text + "  " + m.delta_text)


func test_affordable_row_says_so() -> void:
	var m: FoundryRowModel = _model(_profile(500), 0)
	assert_bool(m.affordable).is_true()
	assert_str(m.afford_text).is_equal("AFFORDABLE")


func test_zero_farm_rate_shows_no_afford_in_time() -> void:
	var p: PlayerProfile = _profile(5)
	p.farm_rate_1x = 0.0
	assert_str(_model(p, 0).afford_text).is_equal("")
	p.farm_rate_1x = 10.0
	assert_str(_model(p, 0).afford_text).contains("TO AFFORD")


func test_row_at_cap_shows_max_and_no_cost() -> void:
	var p: PlayerProfile = _profile(0)
	p.set_foundry_level("laser_output", 200)
	var m: FoundryRowModel = _model(p, 0)
	assert_bool(m.maxed).is_true()
	assert_str(m.cost_text).is_equal("MAX")
	assert_str(m.milestone_text).is_equal("MAX")
	assert_str(m.afford_text).is_equal("")
	assert_str(m.delta_text).is_equal("")
	assert_bool(m.affordable).is_false()
	assert_bool(m.recommended).is_false()


func test_type_c_row_has_start_values_and_no_milestone() -> void:
	var m: FoundryRowModel = _model(_profile(0), 1)
	assert_str(m.name_text).is_equal("CYCLE RATE")
	assert_str(m.milestone_text).is_equal("")
	assert_str(m.value_text).contains("->")
	assert_bool(m.value_text.contains("x1.")).is_false()


func test_tooltips_carry_level_cost_and_cap() -> void:
	var p: PlayerProfile = _profile(0)
	p.set_foundry_level("laser_output", 3)
	var d: String = _model(p, 0).tooltip_text
	assert_str(d).contains("Level F3")
	assert_str(d).contains("Cap F200")
	assert_str(d).contains("Next level costs 27 data")
	assert_str(_model(p, 1).tooltip_text).contains("free levels")


func test_recommended_flag_is_copied() -> void:
	var p: PlayerProfile = _profile(1000)
	p.best_wave["1"] = 100
	p.set_foundry_level("laser_output", 22)
	var views: Array[FoundryRowView] = _service().rows(p)
	assert_bool(FoundryRowModel.from_view(views[0], 0).recommended).is_true()
	assert_bool(FoundryRowModel.from_view(views[2], 2).recommended).is_false()


func test_capped_row_texts() -> void:
	var p: PlayerProfile = _profile(1000)
	p.best_wave["1"] = 10  # cap 6
	p.set_foundry_level("laser_output", 6)
	var m: FoundryRowModel = _model(p, 0)
	assert_bool(m.capped).is_true()
	assert_bool(m.affordable).is_false()
	assert_bool(m.recommended).is_false()
	assert_str(m.afford_text).is_equal("NEXT LEVEL AT WAVE 12")
	assert_str(m.cost_text).is_equal("CAP")
	assert_str(m.tooltip_text).contains("Reach wave 12")
