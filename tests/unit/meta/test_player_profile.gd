class_name TestPlayerProfile
extends GdUnitTestSuite
## PlayerProfile (M3-03): banking, best wave, serialization, validation, frames, clock stubs.


func _summary(id: int, wave: int, data_text: String, ticks: int = 0) -> RunSummary:
	return RunSummary.make(id, wave, BigNum.parse(data_text), ticks)


func test_bank_twice_same_id_adds_once() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(100, "dev")
	assert_bool(p.bank_run(_summary(1, 5, "100"))).is_true()
	assert_bool(p.bank_run(_summary(1, 5, "100"))).is_false()
	assert_bool(p.data.eq(BigNum.parse("100"))).is_true()
	assert_bool(p.lifetime_data.eq(BigNum.parse("100"))).is_true()
	assert_int(p.runs_total).is_equal(1)


func test_ids_in_order_and_older_ignored() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "d")
	assert_bool(p.bank_run(_summary(1, 3, "10"))).is_true()
	assert_bool(p.bank_run(_summary(2, 3, "10"))).is_true()
	assert_bool(p.bank_run(_summary(3, 3, "10"))).is_true()
	assert_bool(p.bank_run(_summary(2, 3, "10"))).is_false()
	assert_bool(p.data.eq(BigNum.parse("30"))).is_true()
	assert_int(p.last_banked_run).is_equal(3)
	assert_int(p.runs_total).is_equal(3)


func test_begin_run_increments() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "d")
	assert_int(p.begin_run()).is_equal(1)
	assert_int(p.begin_run()).is_equal(2)
	assert_int(p.run_counter).is_equal(2)


func test_best_wave_keeps_max() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "d")
	assert_int(p.best_wave_s1()).is_equal(0)
	assert_bool(p.bank_run(_summary(1, 9, "1"))).is_true()
	assert_bool(p.bank_run(_summary(2, 7, "1"))).is_true()
	assert_int(p.best_wave_s1()).is_equal(9)


func test_no_progress_run_changes_nothing() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "d")
	var s: RunSummary = _summary(1, 40, "999")
	s.counts_for_progress = false
	assert_bool(p.bank_run(s)).is_false()
	assert_bool(p.data.is_zero()).is_true()
	assert_int(p.best_wave_s1()).is_equal(0)
	assert_int(p.runs_total).is_equal(0)
	assert_int(p.last_banked_run).is_equal(-1)
	assert_bool(p.has_progress()).is_false()


func test_big_data_exact_and_round_trip() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "d")
	p.data = BigNum.parse("1.5e12")
	assert_bool(p.bank_run(_summary(1, 4, "3"))).is_true()
	assert_bool(p.data.eq(BigNum.parse("1500000000003"))).is_true()
	var q: PlayerProfile = PlayerProfile.from_dict(p.to_dict())
	assert_bool(q.data.eq(p.data)).is_true()
	assert_bool(q.data.eq(BigNum.parse("1500000000003"))).is_true()
	assert_int(q.load_errors.size()).is_equal(0)


func test_full_round_trip() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(500, "dev-1")
	p.flux = 3
	p.cipher = 4
	p.merit = 5
	p.set_foundry_level("laser_output", 7)
	p.settings = {"music": 0.5}
	assert_bool(p.unlock_frame("bulwark")).is_true()
	assert_bool(p.select_frame("bulwark")).is_true()
	assert_int(p.begin_run()).is_equal(1)
	assert_bool(p.bank_run(_summary(1, 8, "250", 3600))).is_true()
	p.touch(900)
	var q: PlayerProfile = PlayerProfile.from_dict(p.to_dict())
	assert_dict(q.to_dict()).is_equal(p.to_dict())
	assert_int(q.foundry_level("laser_output")).is_equal(7)
	assert_str(q.frame_selected).is_equal("bulwark")
	assert_int(q.last_active_utc).is_equal(900)
	assert_str(q.device_id).is_equal("dev-1")
	assert_int(q.created_utc).is_equal(500)
	assert_int(q.load_errors.size()).is_equal(0)


func test_garbage_falls_back_and_is_listed() -> void:
	var d: Dictionary = {
		"data": 12,
		"flux": "x",
		"cipher": -4,
		"runs_total": 2.5,
		"foundry": {"a": -3, "b": 2, "c": "z", 5: 1},
		"best_wave": [],
		"farm_rate_1x": "fast",
		"settings": 7,
		"device_id": 9,
	}
	var p: PlayerProfile = PlayerProfile.from_dict(d)
	assert_bool(p.data.is_zero()).is_true()
	assert_int(p.flux).is_equal(0)
	assert_int(p.cipher).is_equal(0)
	assert_int(p.runs_total).is_equal(0)
	assert_dict(p.foundry).is_equal({"b": 2})
	assert_dict(p.best_wave).is_empty()
	assert_float(p.farm_rate_1x).is_equal(0.0)
	assert_dict(p.settings).is_empty()
	assert_str(p.device_id).is_equal("")
	assert_bool(p.load_errors.size() >= 7).is_true()


func test_bad_bignum_text_is_error() -> void:
	var p: PlayerProfile = PlayerProfile.from_dict({"data": "abc", "lifetime_data": "-5"})
	assert_bool(p.data.is_zero()).is_true()
	assert_int(p.load_errors.size()).is_equal(2)


func test_unknown_keys_round_trip() -> void:
	var p: PlayerProfile = PlayerProfile.from_dict({"future_thing": {"a": 1}, "zeta": "z"})
	assert_int(p.load_errors.size()).is_equal(0)
	var d: Dictionary = p.to_dict()
	var fut: Dictionary = d["future_thing"]
	var zeta: String = d["zeta"]
	assert_dict(fut).is_equal({"a": 1})
	assert_str(zeta).is_equal("z")


func test_farm_rate_ema() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "d")
	# run 1: 600 data in 2 game minutes (3600 ticks) -> 300/min (the first sample seeds the rate)
	assert_bool(p.bank_run(_summary(1, 5, "600", 3600))).is_true()
	assert_float(p.farm_rate_1x).is_equal_approx(300.0, 0.001)
	# run 2: 100 data in 1 game minute -> 0.4 * 100 + 0.6 * 300 = 220
	assert_bool(p.bank_run(_summary(2, 5, "100", 1800))).is_true()
	assert_float(p.farm_rate_1x).is_equal_approx(220.0, 0.001)
	# a zero-tick run does not move it
	assert_bool(p.bank_run(_summary(3, 5, "100", 0))).is_true()
	assert_float(p.farm_rate_1x).is_equal_approx(220.0, 0.001)


func test_foundry_levels() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "d")
	p.set_foundry_level("x", 3)
	assert_int(p.foundry_level("x")).is_equal(3)
	assert_bool(p.has_progress()).is_true()
	p.set_foundry_level("x", -2)
	assert_bool(p.foundry.has("x")).is_false()
	assert_int(p.foundry_level("x")).is_equal(0)


func test_frames_default_and_rules() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "d")
	assert_array(p.frames_unlocked).is_equal(["vanguard"])
	assert_str(p.frame_selected).is_equal("vanguard")
	assert_bool(p.select_frame("bulwark")).is_false()
	assert_bool(p.unlock_frame("bulwark")).is_true()
	assert_bool(p.unlock_frame("bulwark")).is_false()
	assert_bool(p.select_frame("bulwark")).is_true()
	assert_str(p.frame_selected).is_equal("bulwark")


func test_frames_validation() -> void:
	var p: PlayerProfile = PlayerProfile.from_dict({"frames_unlocked": [], "frame_selected": "striker"})
	assert_array(p.frames_unlocked).is_equal(["vanguard"])
	assert_str(p.frame_selected).is_equal("vanguard")
	assert_bool(p.load_errors.size() >= 2).is_true()
	var q: PlayerProfile = PlayerProfile.from_dict({"frames_unlocked": ["vanguard", 3, "bulwark", "bulwark"]})
	assert_array(q.frames_unlocked).is_equal(["vanguard", "bulwark"])
	assert_int(q.load_errors.size()).is_equal(1)
	var missing: PlayerProfile = PlayerProfile.from_dict({})
	assert_array(missing.frames_unlocked).is_equal(["vanguard"])
	assert_int(missing.load_errors.size()).is_equal(0)


func test_fake_clock_drives_last_active() -> void:
	var clk: FakeClock = FakeClock.new(1000)
	var p: PlayerProfile = PlayerProfile.fresh(clk.now_utc(), "d")
	clk.advance(60)
	p.touch(clk.now_utc())
	assert_int(p.last_active_utc).is_equal(1060)
	assert_int(clk.monotonic_ms()).is_equal(60000)
	assert_bool(clk.is_trusted()).is_false()
