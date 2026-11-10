class_name TestFlightRecorder
extends GdUnitTestSuite
## R1-08: the 30-day flight recorder in `profile.extra` and the play summary text.

const DAY: int = 86400
const NOV10: int = 1794268800  ## 2026-11-10 00:00 UTC


func _profile() -> PlayerProfile:
	return PlayerProfile.new()


func test_day_key_is_the_utc_date() -> void:
	assert_str(FlightRecorder.day_key(0)).is_equal("1970-01-01")
	assert_str(FlightRecorder.day_key(-1)).is_equal("1969-12-31")
	assert_str(FlightRecorder.day_key(951868800)).is_equal("2000-03-01")
	assert_str(FlightRecorder.day_key(1709164800)).is_equal("2024-02-29")
	assert_str(FlightRecorder.day_key(NOV10)).is_equal("2026-11-10")
	assert_str(FlightRecorder.day_key(NOV10 + DAY - 1)).is_equal("2026-11-10")
	assert_str(FlightRecorder.day_key(NOV10 + DAY)).is_equal("2026-11-11")


func test_counters_accumulate_within_a_day() -> void:
	var p: PlayerProfile = _profile()
	var clock := FakeClock.new(NOV10 + 3600)
	FlightRecorder.note_session(p, clock)
	FlightRecorder.note_session(p, clock)
	FlightRecorder.note_run(p, clock, "timed", 12)
	FlightRecorder.note_run(p, clock, "timed", 30)
	FlightRecorder.note_run(p, clock, "purge", 8)
	FlightRecorder.note_seconds(p, clock, 90)
	FlightRecorder.note_seconds(p, clock, 40)
	var days: Dictionary = FlightRecorder.days(p)
	assert_int(days.size()).is_equal(1)
	var d: Dictionary = days["2026-11-10"]
	assert_int(FlightRecorder.int_of(d, "s")).is_equal(2)
	assert_int(FlightRecorder.int_of(d, "sec")).is_equal(130)
	assert_int(FlightRecorder.int_of(d, "b")).is_equal(30)
	var runs: Dictionary = d["r"]
	assert_int(FlightRecorder.int_of(runs, "timed")).is_equal(2)
	assert_int(FlightRecorder.int_of(runs, "purge")).is_equal(1)


func test_day_rollover_starts_a_new_day() -> void:
	var p: PlayerProfile = _profile()
	var clock := FakeClock.new(NOV10 + DAY - 10)
	FlightRecorder.note_session(p, clock)
	clock.advance(20)  # past UTC midnight
	FlightRecorder.note_session(p, clock)
	FlightRecorder.note_run(p, clock, "timed", 5)
	var days: Dictionary = FlightRecorder.days(p)
	assert_array(days.keys()).contains_exactly_in_any_order(["2026-11-10", "2026-11-11"])
	var first: Dictionary = days["2026-11-10"]
	var second: Dictionary = days["2026-11-11"]
	assert_int(FlightRecorder.int_of(first, "s")).is_equal(1)
	assert_int(FlightRecorder.int_of(first, "b")).is_equal(0)
	assert_int(FlightRecorder.int_of(second, "s")).is_equal(1)
	assert_int(FlightRecorder.int_of(second, "b")).is_equal(5)


func test_ring_keeps_the_last_30_days_only() -> void:
	var p: PlayerProfile = _profile()
	var clock := FakeClock.new(NOV10)
	for i: int in 45:
		FlightRecorder.note_session(p, clock)
		clock.advance(DAY)
	var days: Dictionary = FlightRecorder.days(p)
	assert_int(days.size()).is_equal(FlightRecorder.KEEP_DAYS)
	var keys: Array = days.keys()
	keys.sort()
	assert_str(str(keys[keys.size() - 1])).is_equal(FlightRecorder.day_key(NOV10 + 44 * DAY))
	assert_str(str(keys[0])).is_equal(FlightRecorder.day_key(NOV10 + 15 * DAY))
	# A long absence drops everything old at the next write.
	clock.advance(100 * DAY)
	FlightRecorder.note_session(p, clock)
	assert_int(FlightRecorder.days(p).size()).is_equal(1)


func test_deepest_screen_wins_and_last_screen_is_the_latest() -> void:
	var p: PlayerProfile = _profile()
	var clock := FakeClock.new(NOV10)
	for s: String in ["title", "home", "battle", "results", "home", "settings"]:
		FlightRecorder.note_screen(p, clock, s)
	var d: Dictionary = FlightRecorder.days(p)["2026-11-10"]
	assert_str(str(d["d"])).is_equal("results")
	assert_str(str(d["l"])).is_equal("settings")


func test_survives_a_json_round_trip_and_damaged_data() -> void:
	var p: PlayerProfile = _profile()
	var clock := FakeClock.new(NOV10)
	FlightRecorder.note_session(p, clock)
	FlightRecorder.note_run(p, clock, "timed", 9)
	var text: String = JSON.stringify(p.extra)
	var back: Variant = JSON.parse_string(text)
	var p2: PlayerProfile = _profile()
	p2.extra = back  # numbers come back as floats
	FlightRecorder.note_session(p2, clock)
	var d: Dictionary = FlightRecorder.days(p2)["2026-11-10"]
	assert_int(FlightRecorder.int_of(d, "s")).is_equal(2)
	assert_int(FlightRecorder.int_of(d, "b")).is_equal(9)
	var p3: PlayerProfile = _profile()
	p3.extra[FlightRecorder.KEY] = "garbage"
	FlightRecorder.note_session(p3, clock)  # repaired, no crash
	assert_int(FlightRecorder.days(p3).size()).is_equal(1)
	var p4: PlayerProfile = _profile()
	p4.extra[FlightRecorder.KEY] = {"v": 1, "days": {"2026-11-10": 5}}
	FlightRecorder.note_run(p4, clock, "timed", 3)
	var d4: Dictionary = FlightRecorder.days(p4)["2026-11-10"]
	assert_int(FlightRecorder.int_of(d4, "b")).is_equal(3)


func test_summary_text_format() -> void:
	var p: PlayerProfile = _profile()
	var clock := FakeClock.new(NOV10 + 100)
	FlightRecorder.note_session(p, clock)
	FlightRecorder.note_screen(p, clock, "home")
	FlightRecorder.note_run(p, clock, "timed", 38)
	FlightRecorder.note_screen(p, clock, "results")
	FlightRecorder.note_seconds(p, clock, 1860)
	clock.advance(DAY)
	FlightRecorder.note_session(p, clock)
	FlightRecorder.note_run(p, clock, "purge", 12)
	FlightRecorder.note_screen(p, clock, "foundry")
	FlightRecorder.note_seconds(p, clock, 600)
	var lines: PackedStringArray = PlaySummary.build(p, clock, "0.5.0-beta.1").split("\n")
	assert_str(lines[0]).is_equal("IRON STATIC PLAY SUMMARY")
	assert_str(lines[1]).is_equal("Version 0.5.0-beta.1, 2026-11-11 UTC")
	assert_str(lines[2]).is_equal("Last 30 days: 2 days played, 2 sessions, 41 min")
	assert_str(lines[3]).is_equal("Runs: purge 1, timed 1")
	assert_str(lines[4]).starts_with("Best wave in that time: 38 (all-time timed ")
	assert_str(lines[5]).is_equal("Deepest screen: results. Last screen before quit: foundry.")
	assert_str(lines[6]).is_equal("2026-11-11  sessions 1  min 10  runs 1  best 12  last foundry")
	assert_str(lines[7]).is_equal("2026-11-10  sessions 1  min 31  runs 1  best 38  last results")
	assert_int(lines.size()).is_equal(8)


func test_summary_without_data_and_with_many_days() -> void:
	var p: PlayerProfile = _profile()
	var clock := FakeClock.new(NOV10)
	var text: String = PlaySummary.build(p, clock, "v")
	assert_str(text).contains("No play recorded yet.")
	for i: int in 20:
		FlightRecorder.note_session(p, clock)
		clock.advance(DAY)
	var lines: PackedStringArray = PlaySummary.build(p, clock, "v").split("\n")
	assert_int(lines.size()).is_equal(6 + PlaySummary.RECENT_DAYS)
	assert_str(PlaySummary.build(p, clock, "v")).contains("Runs: none")
