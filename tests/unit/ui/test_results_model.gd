class_name TestResultsModel
extends GdUnitTestSuite
## ResultsModel with BankedInfo (M3-17): best delta and flag, banked data line, Foundry button, chip, warning.


func _model(death_wave: int, prev: int, affordable: int = 0, unlocked: bool = true) -> ResultsModel:
	var run := RunStats.new()
	run.death_wave = death_wave
	var eco := EconomyState.new()
	eco.data_run = BigNum.from_int(1234)
	var info := BankedInfo.new()
	info.has_bank = true
	info.previous_best = prev
	info.new_best = maxi(prev, death_wave)
	info.data_total = BigNum.from_int(5678)
	info.affordable_count = affordable
	info.foundry_unlocked = unlocked
	return ResultsModel.from_run(run, eco, 900, "", info)


func test_new_best_shows_delta_and_flag() -> void:
	var m: ResultsModel = _model(12, 9)
	assert_str(m.best_text).is_equal("BEST 12  (+3)")
	assert_bool(m.new_best).is_true()


func test_lower_wave_keeps_best_without_flag() -> void:
	var m: ResultsModel = _model(7, 12)
	assert_str(m.best_text).is_equal("BEST 12")
	assert_bool(m.new_best).is_false()


func test_first_death_is_a_delta_against_zero() -> void:
	var m: ResultsModel = _model(5, 0)
	assert_str(m.best_text).is_equal("BEST 5  (+5)")
	assert_bool(m.new_best).is_true()


func test_banked_text_uses_number_format_and_total() -> void:
	var m: ResultsModel = _model(5, 0)
	var v: String = NumberFormat.format(BigNum.from_int(1234))
	var t: String = NumberFormat.format(BigNum.from_int(5678))
	assert_str(m.data_text).is_equal("DATA +%s  TOTAL %s" % [v, t])
	assert_str(m.data_line("7")).is_equal("DATA +7  TOTAL %s" % t)


func test_foundry_button_carries_count_and_pulses_only_above_zero() -> void:
	var some: ResultsModel = _model(5, 0, 3)
	assert_str(some.foundry_text).is_equal("FOUNDRY  3 AFFORDABLE")
	assert_bool(some.foundry_pulse).is_true()
	var none: ResultsModel = _model(5, 0, 0)
	assert_str(none.foundry_text).is_equal("FOUNDRY")
	assert_bool(none.foundry_pulse).is_false()
	assert_bool(none.foundry_visible).is_true()


func test_foundry_hidden_when_locked() -> void:
	var m: ResultsModel = _model(5, 0, 2, false)
	assert_bool(m.foundry_visible).is_false()
	assert_bool(m.foundry_pulse).is_false()


func test_debug_run_has_dashes_and_no_bank_line() -> void:
	var run := RunStats.new()
	var m: ResultsModel = ResultsModel.from_run(run, EconomyState.new(), 0, "")
	assert_str(m.best_text).is_equal("BEST  --")
	assert_bool(m.new_best).is_false()
	assert_bool(m.data_text.contains("TOTAL")).is_false()
	assert_bool(m.foundry_visible).is_false()


func test_chip_and_save_warning() -> void:
	var run := RunStats.new()
	var info := BankedInfo.new()
	info.has_bank = true
	info.unlocked_frames = ["bulwark"]
	info.save_failed = true
	var m: ResultsModel = ResultsModel.from_run(run, EconomyState.new(), 0, "", info)
	assert_str(m.chip_text).is_equal("FRAME UNLOCKED: BULWARK")
	assert_str(m.save_warning_text).is_equal("SAVE PROBLEM")
	var clean := BankedInfo.new()
	clean.has_bank = true
	var m2: ResultsModel = ResultsModel.from_run(run, EconomyState.new(), 0, "", clean)
	assert_str(m2.chip_text).is_equal("")
	assert_str(m2.save_warning_text).is_equal("")
