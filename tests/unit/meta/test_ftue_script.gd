class_name TestFtueScript
extends GdUnitTestSuite
## FtueScript and FtueState (M4-25): the 07 s3 beat order, skip, the two-run limit, persistence in profile `extra`.

var _script: FtueScript = FtueScript.load_default()


func _fresh() -> FtueState:
	return FtueState.load_from(_script, PlayerProfile.fresh(0, "t"))


func _ids(beats: Array[FtueBeatDef]) -> Array[String]:
	var out: Array[String] = []
	for b: FtueBeatDef in beats:
		out.append(b.id)
	return out


func test_fresh_state_starts_at_cold_open() -> void:
	var s: FtueState = _fresh()
	assert_str(s.current_id()).is_equal("cold_open")
	assert_bool(s.cold_open_due()).is_true()
	assert_bool(s.enabled()).is_true()
	assert_object(s.active()).is_null()


func test_events_advance_the_beats_in_the_07_s3_order() -> void:
	var s: FtueState = _fresh()
	var seen: Array[String] = []
	var steps: Array[String] = [
		FtueScript.COLD_OPEN,
		FtueScript.RUN1_START,
		FtueScript.FIRST_KILL,
		FtueScript.SCRAP_AFFORDS_CYCLE_RATE,
		FtueScript.DART_FIRST_SEEN,
		FtueScript.FIRST_DAMAGE_TAKEN,
		FtueScript.DRAFT_OPEN_FIRST,
		FtueScript.DEATH_FIRST,
		FtueScript.RESULTS_FIRST,
		FtueScript.FOUNDRY_FIRST,
	]
	for trigger: String in steps:
		for b: FtueBeatDef in s.on_event(trigger):
			seen.append(b.id)
		while s.active() != null:
			assert_bool(s.complete(s.active().id)).is_true()
	(
		assert_array(seen)
		. is_equal(
			[
				"cold_open",
				"upgrade_laser",
				"first_kill",
				"upgrade_rate",
				"dart_label",
				"upgrade_hull",
				"hold_hint",
				"draft_note",
				"death_note",
				"results_foundry",
				"foundry_hold",
			]
		)
	)
	assert_str(s.current_id()).is_equal("run2_note")


func test_current_id_follows_completion() -> void:
	var s: FtueState = _fresh()
	assert_array(_ids(s.on_event(FtueScript.COLD_OPEN))).is_equal(["cold_open"])
	assert_str(s.current_id()).is_equal("cold_open")
	assert_bool(s.complete("cold_open")).is_true()
	assert_str(s.current_id()).is_equal("upgrade_laser")
	assert_bool(s.cold_open_due()).is_false()
	assert_array(_ids(s.begin_run(0))).is_equal(["upgrade_laser"])
	assert_str(s.active().id).is_equal("upgrade_laser")


func test_silent_beats_complete_at_once_and_never_block() -> void:
	var s: FtueState = _fresh()
	assert_array(_ids(s.on_event(FtueScript.FIRST_KILL))).is_equal(["first_kill"])
	assert_bool(s.is_done("first_kill")).is_true()
	assert_object(s.active()).is_null()
	assert_array(_ids(s.on_event(FtueScript.DRAFT_OPEN_FIRST))).is_equal(["draft_note"])
	assert_object(s.active()).is_null()
	assert_array(_ids(s.on_event(FtueScript.FIRST_KILL))).is_empty()  # once only


func test_same_trigger_queues_in_csv_order() -> void:
	var s: FtueState = _fresh()
	assert_array(_ids(s.on_event(FtueScript.FIRST_DAMAGE_TAKEN))).is_equal(["upgrade_hull", "hold_hint"])
	assert_str(s.active().id).is_equal("upgrade_hull")
	assert_int(s.queued_count()).is_equal(1)
	assert_bool(s.row_bought("hull_integrity")).is_true()
	assert_str(s.active().id).is_equal("hold_hint")
	assert_bool(s.row_bought("laser_output")).is_false()  # not the active row
	assert_bool(s.complete("hold_hint")).is_true()
	assert_object(s.active()).is_null()


func test_a_beat_expires_after_display_time_and_results_pulse_does_not() -> void:
	var s: FtueState = _fresh()
	@warning_ignore("return_value_discarded")
	s.on_event(FtueScript.DART_FIRST_SEEN)
	s.advance(FtueState.DISPLAY_S - 0.5)
	assert_str(s.active().id).is_equal("dart_label")
	s.advance(1.0)
	assert_object(s.active()).is_null()
	assert_bool(s.is_done("dart_label")).is_true()
	@warning_ignore("return_value_discarded")
	s.on_event(FtueScript.RESULTS_FIRST)
	s.advance(600.0)
	assert_str(s.active().id).is_equal("results_foundry")


func test_skip_all_ends_every_beat_and_persists() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	var s: FtueState = FtueState.load_from(_script, p)
	@warning_ignore("return_value_discarded")
	s.on_event(FtueScript.FIRST_DAMAGE_TAKEN)
	s.skip_all()
	assert_object(s.active()).is_null()
	assert_int(s.queued_count()).is_equal(0)
	assert_bool(s.enabled()).is_false()
	assert_array(s.on_event(FtueScript.DART_FIRST_SEEN)).is_empty()
	assert_array(s.begin_run(0)).is_empty()
	assert_bool(s.dirty).is_true()
	s.store_to(p)
	assert_bool(s.dirty).is_false()
	var again: FtueState = FtueState.load_from(_script, p)
	assert_bool(again.skipped).is_true()
	assert_bool(again.cold_open_due()).is_false()
	assert_str(again.current_id()).is_equal("")


func test_a_profile_with_three_runs_shows_no_beats() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	p.runs_total = 3
	var s: FtueState = FtueState.load_from(_script, p)
	assert_bool(s.enabled()).is_false()
	assert_bool(s.cold_open_due()).is_false()
	for trigger: String in FtueScript.TRIGGERS:
		assert_array(s.on_event(trigger)).is_empty()
	assert_array(s.begin_run(3)).is_empty()
	assert_object(s.active()).is_null()


func test_hull_hint_fires_on_first_damage_in_any_of_the_first_three_runs() -> void:
	# R1-07 (O-04): runs 1 and 2 may pass without damage; run 3 still shows the hull hint, and nothing else.
	for banked: int in [0, 1, 2]:
		var p: PlayerProfile = PlayerProfile.fresh(0, "t")
		p.runs_total = banked
		var s: FtueState = FtueState.load_from(_script, p)
		@warning_ignore("return_value_discarded")
		s.begin_run(banked)
		assert_bool(s.enabled()).is_true()
		var shown: Array[String] = _ids(s.on_event(FtueScript.FIRST_DAMAGE_TAKEN))
		if banked < 2:
			assert_array(shown).is_equal(["upgrade_hull", "hold_hint"])
		else:
			assert_array(shown).is_equal(["upgrade_hull"])
			assert_str(s.active().id).is_equal("upgrade_hull")
	# Run 3: the other triggers stay silent.
	var late: PlayerProfile = PlayerProfile.fresh(0, "t")
	late.runs_total = 2
	var s3: FtueState = FtueState.load_from(_script, late)
	for trigger: String in [FtueScript.DART_FIRST_SEEN, FtueScript.DRAFT_OPEN_FIRST, FtueScript.RESULTS_FIRST]:
		assert_array(s3.on_event(trigger)).is_empty()
	# Once shown (done) it does not come back in a later run.
	@warning_ignore("return_value_discarded")
	s3.on_event(FtueScript.FIRST_DAMAGE_TAKEN)
	@warning_ignore("return_value_discarded")
	s3.complete("upgrade_hull")
	assert_array(s3.on_event(FtueScript.FIRST_DAMAGE_TAKEN)).is_empty()


func test_hull_hint_texts_carry_a_verb_and_a_reason() -> void:
	assert_str(Strings.get_text(_script.beat("upgrade_laser").text_key)).is_equal("TAP: MORE DAMAGE")
	assert_str(Strings.get_text(_script.beat("upgrade_rate").text_key)).is_equal("TAP: FIRE FASTER")
	assert_str(Strings.get_text(_script.beat("upgrade_hull").text_key)).is_equal("TAP: SURVIVE LONGER")


func test_a_queued_hint_for_a_row_the_player_already_bought_is_dropped() -> void:
	# R1-02: with 230 start scrap the player can buy cycle rate while its hint waits behind the laser hint.
	var s: FtueState = _fresh()
	@warning_ignore("return_value_discarded")
	s.begin_run(0)
	assert_str(s.active().id).is_equal("upgrade_laser")
	assert_array(_ids(s.on_event(FtueScript.SCRAP_AFFORDS_CYCLE_RATE))).is_equal(["upgrade_rate"])
	assert_int(s.queued_count()).is_equal(1)
	assert_bool(s.row_bought("cycle_rate")).is_false()
	assert_int(s.queued_count()).is_equal(0)
	assert_bool(s.is_done("upgrade_rate")).is_true()
	assert_bool(s.row_bought("laser_output")).is_true()
	assert_object(s.active()).is_null()  # nothing left to show


func test_run_two_shows_only_beats_that_allow_it() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	p.runs_total = 1
	var s: FtueState = FtueState.load_from(_script, p)
	assert_bool(s.cold_open_due()).is_false()  # an existing profile never sees the cold open
	assert_array(_ids(s.begin_run(1))).is_equal(["run2_note"])
	assert_array(s.on_event(FtueScript.RUN1_START)).is_empty()  # max_runs 1
	assert_array(_ids(s.on_event(FtueScript.DART_FIRST_SEEN))).is_equal(["dart_label"])
	assert_array(s.begin_run(2)).is_empty()  # run 3: nothing


func test_state_round_trips_through_profile_extra() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	var s: FtueState = FtueState.load_from(_script, p)
	@warning_ignore("return_value_discarded")
	s.on_event(FtueScript.COLD_OPEN)
	@warning_ignore("return_value_discarded")
	s.complete("cold_open")
	@warning_ignore("return_value_discarded")
	s.on_event(FtueScript.FIRST_KILL)
	s.store_to(p)
	var d: Dictionary = p.to_dict()
	var back: PlayerProfile = PlayerProfile.from_dict(d)
	assert_bool(back.extra.has(FtueState.KEY)).is_true()
	var loaded: FtueState = FtueState.load_from(_script, back)
	assert_bool(loaded.is_done("cold_open")).is_true()
	assert_bool(loaded.is_done("first_kill")).is_true()
	assert_bool(loaded.is_done("upgrade_laser")).is_false()
	assert_bool(loaded.skipped).is_false()
	assert_str(loaded.current_id()).is_equal("upgrade_laser")


func test_damaged_extra_is_a_fresh_state() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	p.extra[FtueState.KEY] = "garbage"
	assert_str(FtueState.load_from(_script, p).current_id()).is_equal("cold_open")
	p.extra[FtueState.KEY] = {"done": [3, "no_such_beat", "cold_open"], "skipped": "yes"}
	var s: FtueState = FtueState.load_from(_script, p)
	assert_bool(s.is_done("cold_open")).is_true()
	assert_bool(s.skipped).is_false()


func test_every_text_key_exists_in_strings() -> void:
	assert_int(_script.beats().size()).is_equal(12)
	for b: FtueBeatDef in _script.beats():
		assert_bool(Strings.has_key(b.text_key)).is_true()
		assert_bool(FtueScript.TRIGGERS.has(b.trigger)).is_true()
		assert_bool(b.max_runs >= 1 and b.max_runs <= FtueScript.MAX_RUNS).is_true()
	for key: String in FtueScript.COLD_LINE_KEYS:
		assert_bool(Strings.has_key(key)).is_true()
	assert_str(Strings.get_text("ftue.cold.1")).is_equal("RELAY 06 ONLINE")
	assert_str(Strings.get_text("ftue.dart")).is_equal("DART - FAST")
	# R1-04 note, sentence case since R1-07
	assert_str(Strings.get_text("draft.note")).is_equal("Patches last this deployment. One reroll per draft.")


func test_targets_parse() -> void:
	var laser: FtueBeatDef = _script.beat("upgrade_laser")
	assert_bool(FtueScript.is_row(laser)).is_true()
	assert_str(FtueScript.row_id(laser)).is_equal("laser_output")
	assert_str(FtueScript.foundry_id(_script.beat("foundry_hold"))).is_equal("laser_output")
	assert_bool(FtueScript.is_silent(_script.beat("first_kill"))).is_true()
	assert_bool(FtueScript.is_silent(_script.beat("dart_label"))).is_false()
	assert_object(_script.beat("nope")).is_null()


func test_drop_pending_clears_the_hints_without_finishing_them() -> void:
	var s: FtueState = _fresh()
	@warning_ignore("return_value_discarded")
	s.on_event(FtueScript.FIRST_DAMAGE_TAKEN)
	s.drop_pending()
	assert_object(s.active()).is_null()
	assert_int(s.queued_count()).is_equal(0)
	assert_bool(s.is_done("upgrade_hull")).is_false()
	assert_array(_ids(s.on_event(FtueScript.FIRST_DAMAGE_TAKEN))).is_equal(["upgrade_hull", "hold_hint"])
