class_name TestServiceRecord
extends GdUnitTestSuite
## Service Record storage (lifetime stats in `profile.extra["record"]`): fresh start, seeding an older save,
## commits, JSON round trip with floats, corrupt values, reset, play time through a FakeClock.

const DAY: int = 86400
const NOV10: int = 1794268800  ## 2026-11-10 00:00 UTC


func _totals(mode: String = "timed", frame: String = "vanguard", wave: int = 9) -> RunTotals:
	var t := RunTotals.new()
	t.detail = RunTotals.Detail.FULL
	t.mode = mode
	t.frame_id = frame
	t.ticks = 3000
	t.wave = wave
	t.waves_cleared = wave - 1
	t.kills = {"skitter": 40, "boss_hulk": 1}
	t.bosses = 1
	t.damage = BigNum.from_float(12345.0)
	t.upgrades = 12
	t.patches = 2
	t.shots = 300
	t.crits = 30
	t.hit_max = 77
	t.hull = 55
	t.scrap_in = BigNum.from_float(900.0)
	t.scrap_out = BigNum.from_float(850.0)
	return t


func _json_round_trip(p: PlayerProfile) -> PlayerProfile:
	var text: String = JSON.stringify(p.to_dict())
	var parsed: Variant = JSON.parse_string(text)
	var d: Dictionary = {}
	if parsed is Dictionary:
		d = parsed
	return PlayerProfile.from_dict(d)


func test_a_fresh_profile_starts_an_empty_record_dated_by_its_creation() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(NOV10, "dev")
	ServiceRecord.ensure(p, FakeClock.new(NOV10 + DAY))
	assert_bool(RecordReader.seeded(p)).is_false()
	assert_int(RecordReader.since(p)).is_equal(NOV10)
	assert_int(RecordReader.runs_all(p)).is_equal(0)
	assert_int(RecordReader.kills_all(p)).is_equal(0)
	var again: Dictionary = RecordReader.record(p).duplicate(true)
	ServiceRecord.ensure(p, FakeClock.new(NOV10 + 5 * DAY))  # a current record is never touched
	assert_dict(RecordReader.record(p)).is_equal(again)


func test_an_old_save_is_seeded_from_what_it_already_knows() -> void:
	var p := PlayerProfile.new()
	p.runs_total = 20
	p.best_wave["1"] = 14
	var clock := FakeClock.new(NOV10 + 3600)
	FlightRecorder.note_run(p, clock, "timed", 14)
	FlightRecorder.note_run(p, clock, "timed", 9)
	FlightRecorder.note_run(p, clock, "purge", 6)
	FlightRecorder.note_seconds(p, clock, 700)
	clock.advance(DAY)
	FlightRecorder.note_run(p, clock, "timed", 3)
	FlightRecorder.note_seconds(p, clock, 200)
	ServiceRecord.ensure(p, clock)
	assert_bool(RecordReader.seeded(p)).is_true()
	assert_int(RecordReader.since(p)).is_equal(clock.now_utc())
	assert_int(RecordReader.runs_of_mode(p, "timed")).is_equal(3)
	assert_int(RecordReader.runs_of_mode(p, "purge")).is_equal(1)
	assert_int(RecordReader.runs_before(p)).is_equal(16)  # 20 banked runs, 4 of them in the last 30 days
	assert_int(RecordReader.runs_all(p)).is_equal(20)  # the total always equals the profile's own count
	assert_int(RecordReader.total(p, "play_s")).is_equal(900)
	assert_int(RecordReader.kills_all(p)).is_equal(0)  # not stored by the old save: starts at zero
	assert_int(RecordReader.total(p, "waves")).is_equal(0)


func test_seeding_never_invents_runs_when_the_flight_recorder_counts_more_than_the_profile() -> void:
	var p := PlayerProfile.new()
	p.run_counter = 3
	p.runs_total = 1
	var clock := FakeClock.new(NOV10)
	FlightRecorder.note_run(p, clock, "timed", 5)
	FlightRecorder.note_run(p, clock, "timed", 5)
	ServiceRecord.ensure(p, clock)
	assert_int(RecordReader.runs_before(p)).is_equal(0)


func test_commit_adds_a_banked_run_and_keeps_maxima() -> void:
	var p := PlayerProfile.new()
	ServiceRecord.ensure(p, FakeClock.new(NOV10))
	ServiceRecord.commit_run(p, _totals("timed", "vanguard", 9))
	var second: RunTotals = _totals("purge", "bulwark", 5)
	second.ticks = 9000
	second.hit_max = 20
	ServiceRecord.commit_run(p, second)
	assert_int(RecordReader.runs_of_mode(p, "timed")).is_equal(1)
	assert_int(RecordReader.runs_of_mode(p, "purge")).is_equal(1)
	assert_int(RecordReader.total(p, "deploy_ticks")).is_equal(12000)
	assert_int(RecordReader.total(p, "longest_ticks")).is_equal(9000)
	assert_int(RecordReader.total(p, "waves")).is_equal(8 + 4)
	assert_int(RecordReader.kills_of(p, "skitter")).is_equal(80)
	assert_int(RecordReader.kills_of(p, "boss_hulk")).is_equal(2)
	assert_int(RecordReader.kills_all(p)).is_equal(82)
	assert_int(RecordReader.total(p, "bosses")).is_equal(2)
	assert_int(RecordReader.total(p, "shots")).is_equal(600)
	assert_int(RecordReader.total(p, "crits")).is_equal(60)
	assert_int(RecordReader.total(p, "hit_max")).is_equal(77)
	assert_int(RecordReader.total(p, "hull")).is_equal(110)
	assert_int(RecordReader.total(p, "upgrades")).is_equal(24)
	assert_int(RecordReader.total(p, "patches")).is_equal(4)
	assert_str(RecordReader.total_big(p, "damage").to_text()).is_equal(BigNum.from_float(24690.0).to_text())
	assert_str(RecordReader.total_big(p, "scrap_in").to_text()).is_equal(BigNum.from_float(1800.0).to_text())
	assert_str(RecordReader.total_big(p, "scrap_out").to_text()).is_equal(BigNum.from_float(1700.0).to_text())
	assert_int(RecordReader.frame_runs(p, "vanguard")).is_equal(1)
	assert_int(RecordReader.frame_best(p, "bulwark")).is_equal(5)
	assert_int(RecordReader.total(p, "gaps")).is_equal(0)


func test_incomplete_runs_add_what_they_know_and_count_a_gap() -> void:
	var p := PlayerProfile.new()
	ServiceRecord.ensure(p, FakeClock.new(NOV10))
	var world_only: RunTotals = _totals()
	world_only.detail = RunTotals.Detail.WORLD
	ServiceRecord.commit_run(p, world_only)
	var summary_only: RunTotals = RunTotals.new()
	summary_only.ticks = 600
	summary_only.wave = 3
	summary_only.waves_cleared = 2
	ServiceRecord.commit_run(p, summary_only)
	assert_int(RecordReader.total(p, "gaps")).is_equal(2)
	assert_int(RecordReader.total(p, "shots")).is_equal(0)
	assert_int(RecordReader.kills_all(p)).is_equal(41)
	assert_int(RecordReader.runs_of_mode(p, "timed")).is_equal(2)
	assert_int(RecordReader.total(p, "deploy_ticks")).is_equal(3600)


func test_the_record_survives_a_json_round_trip_with_floats() -> void:
	var p := PlayerProfile.fresh(NOV10, "dev")
	ServiceRecord.ensure(p, FakeClock.new(NOV10))
	ServiceRecord.commit_run(p, _totals())
	ServiceRecord.note_seconds(p, 1234)
	p.extra["future_key"] = {"a": 1}
	var back: PlayerProfile = _json_round_trip(p)
	assert_int(RecordReader.total(back, "play_s")).is_equal(1234)
	assert_int(RecordReader.kills_of(back, "skitter")).is_equal(40)
	assert_int(RecordReader.frame_best(back, "vanguard")).is_equal(9)
	assert_str(RecordReader.total_big(back, "damage").to_text()).is_equal(BigNum.from_float(12345.0).to_text())
	var future: Dictionary = back.extra["future_key"]
	assert_int(RecordReader.int_of(future, "a")).is_equal(1)  # other keys survive
	ServiceRecord.commit_run(back, _totals())  # and the loaded record keeps counting (floats read back as ints)
	assert_int(RecordReader.kills_of(back, "skitter")).is_equal(80)
	assert_int(RecordReader.runs_of_mode(back, "timed")).is_equal(2)


func test_corrupt_values_read_as_zero_and_never_throw() -> void:
	var p := PlayerProfile.new()
	p.extra["record"] = {
		"v": 1.0,
		"since": "yesterday",
		"play_s": -5,
		"runs": "many",
		"kills": {"skitter": "x", "dart": 2.9, "walker": -4, "lancer": null},
		"damage": "garbage",
		"scrap_in": 12,
		"frames": {"vanguard": "oops"},
		"hit_max": NAN,
	}
	assert_int(RecordReader.since(p)).is_equal(0)
	assert_int(RecordReader.total(p, "play_s")).is_equal(0)
	assert_int(RecordReader.runs_all(p)).is_equal(0)
	assert_int(RecordReader.kills_of(p, "skitter")).is_equal(0)
	assert_int(RecordReader.kills_of(p, "dart")).is_equal(2)
	assert_int(RecordReader.kills_of(p, "walker")).is_equal(0)
	assert_bool(RecordReader.total_big(p, "damage").is_zero()).is_true()
	assert_bool(RecordReader.total_big(p, "scrap_in").is_zero()).is_true()
	assert_int(RecordReader.frame_runs(p, "vanguard")).is_equal(0)
	assert_int(RecordReader.total(p, "hit_max")).is_equal(0)
	ServiceRecord.commit_run(p, _totals())  # committing into a damaged record repairs it
	assert_int(RecordReader.runs_of_mode(p, "timed")).is_equal(1)
	assert_int(RecordReader.kills_of(p, "skitter")).is_equal(40)
	assert_int(RecordReader.frame_runs(p, "vanguard")).is_equal(1)
	# a record of another version is replaced on the next ensure
	p.extra["record"] = {"v": 99, "play_s": 5}
	ServiceRecord.ensure(p, FakeClock.new(NOV10))
	assert_int(RecordReader.total(p, "play_s")).is_equal(0)
	p.extra["record"] = "not a dictionary"
	ServiceRecord.ensure(p, FakeClock.new(NOV10))
	assert_int(RecordReader.since(p)).is_equal(NOV10)


func test_a_profile_reset_clears_the_record() -> void:
	SaveKey.reset()
	var fs := MemorySaveFs.new()
	var clock := FakeClock.new(NOV10)
	var s := SaveService.new(fs, clock, "dev")
	@warning_ignore("return_value_discarded")
	s.load_profile()
	ServiceRecord.commit_run(s.profile, _totals())
	ServiceRecord.note_seconds(s.profile, 500)
	s.profile.runs_total = 1
	assert_bool(s.save_now()).is_true()
	assert_int(RecordReader.kills_all(s.profile)).is_equal(41)
	clock.advance(2 * DAY)
	assert_bool(s.reset_profile()).is_true()
	assert_int(RecordReader.kills_all(s.profile)).is_equal(0)
	assert_int(RecordReader.total(s.profile, "play_s")).is_equal(0)
	assert_int(RecordReader.runs_all(s.profile)).is_equal(0)
	assert_int(RecordReader.since(s.profile)).is_equal(NOV10 + 2 * DAY)
	assert_bool(RecordReader.seeded(s.profile)).is_false()


func test_loading_a_save_without_a_record_seeds_it_once() -> void:
	SaveKey.reset()
	var fs := MemorySaveFs.new()
	var s := SaveService.new(fs, FakeClock.new(NOV10), "dev")
	@warning_ignore("return_value_discarded")
	s.load_profile()
	s.profile.runs_total = 4
	s.profile.extra.erase("record")  # a save written before the record existed
	assert_bool(s.save_now()).is_true()
	var s2 := SaveService.new(fs, FakeClock.new(NOV10 + DAY), "dev")
	@warning_ignore("return_value_discarded")
	s2.load_profile()
	assert_bool(RecordReader.seeded(s2.profile)).is_true()
	assert_int(RecordReader.runs_before(s2.profile)).is_equal(4)
	assert_bool(s2.save_now()).is_true()
	var s3 := SaveService.new(fs, FakeClock.new(NOV10 + 9 * DAY), "dev")
	@warning_ignore("return_value_discarded")
	s3.load_profile()
	assert_int(RecordReader.since(s3.profile)).is_equal(NOV10 + DAY)  # the seeding date, kept


func test_play_time_counts_foreground_seconds_through_the_clock() -> void:
	var clock := FakeClock.new(NOV10)
	var timer := PlayTimer.new()
	timer.sample(clock)  # anchors
	for i: int in 90:  # 90 frames of 0.5 s
		clock.mono_ms += 500
		timer.sample(clock)
	assert_int(timer.take_seconds()).is_equal(45)
	clock.mono_ms += 600
	timer.sample(clock)
	assert_int(timer.take_seconds()).is_equal(0)  # 0.6 s, the remainder is kept
	clock.mono_ms += 600
	timer.sample(clock)
	assert_int(timer.take_seconds()).is_equal(1)  # 1.2 s in all
	# the app sleeps for ten minutes: the gap counts at most one second, and a suspend counts nothing
	clock.mono_ms += 600000
	timer.sample(clock)
	assert_int(timer.take_seconds()).is_equal(1)  # 0.2 s left + the 1 s cap, not ten minutes
	timer.suspend()
	clock.mono_ms += 600000
	timer.sample(clock)
	assert_int(timer.take_seconds()).is_equal(0)
	var p := PlayerProfile.new()
	ServiceRecord.note_seconds(p, 45)
	ServiceRecord.note_seconds(p, 0)
	ServiceRecord.note_seconds(p, -3)
	assert_int(RecordReader.total(p, "play_s")).is_equal(45)
