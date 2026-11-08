class_name TestHudModel
extends GdUnitTestSuite
## HudModel and ResultsModel (M2-11).


func test_scrap_12400_formats_as_12_4k() -> void:
	var m := HudModel.new()
	m.set_values(3, 80.0, 100.0, BigNum.from_float(12400.0), BigNum.from_float(1234.0))
	assert_str(m.scrap_text).is_equal("SCRAP 12.4K")
	assert_str(m.data_text).is_equal("DATA 1.23K")
	assert_str(m.wave_text).is_equal("WAVE 3")
	assert_str(m.hp_text).is_equal("80 / 100")


func test_update_is_throttled_to_ten_hz_and_keeps_cached_text() -> void:
	var m := HudModel.new()
	assert_bool(m.update(0.0, 1, 10.0, 10.0, BigNum.from_float(5.0), BigNum.zero())).is_true()
	assert_str(m.scrap_text).is_equal("SCRAP 5")
	assert_bool(m.update(0.05, 1, 10.0, 10.0, BigNum.from_float(900.0), BigNum.zero())).is_false()
	assert_str(m.scrap_text).is_equal("SCRAP 5")
	assert_bool(m.update(0.11, 1, 10.0, 10.0, BigNum.from_float(900.0), BigNum.zero())).is_true()
	assert_str(m.scrap_text).is_equal("SCRAP 900")


func test_results_text_matches_layout_fields() -> void:
	var run := RunStats.new()
	run.death_wave = 47
	run.kills = 1204
	run.scrap_earned = 5400.0
	var eco := EconomyState.new()
	eco.data_run = BigNum.from_float(18400.0)
	var m: ResultsModel = ResultsModel.from_run(run, eco, 702 * Ticks.TICK_RATE, "LANCER")
	assert_str(m.title_text).is_equal("DEPLOYMENT ENDED")
	assert_str(m.wave_text).is_equal("WAVE REACHED  47")
	assert_str(m.time_text).is_equal("TIME  11m 42s")
	assert_str(m.kills_text).is_equal("KILLS  1.2K")
	assert_str(m.cause_text).is_equal("CAUSE  LANCER")
	assert_str(m.data_text).is_equal("DATA  +18.4K")
	assert_str(m.scrap_text).is_equal("SCRAP  5.4K")
	assert_str(m.best_text).is_equal("BEST  --")
	assert_str(ResultsModel.from_run(run, eco, 0, "").cause_text).is_equal("CAUSE  UNKNOWN")
