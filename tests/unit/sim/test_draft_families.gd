class_name TestDraftFamilies
extends GdUnitTestSuite
## R1-04: one card per family (ARMS, CHASSIS, SYSTEMS), the fallback when a family is empty, the gamble replacing the
## card of its own family, and the reroll command (log, limit, determinism, replay, snapshot).

const MAX_TICKS: int = 60000


func _cfg(seed_value: int = 3) -> SimConfig:
	var cfg: SimConfig = SimConfigLoader.load_default(seed_value)
	cfg.debug_invulnerable = true
	return cfg


func _to_draft(w: SimWorld) -> void:
	while not w.is_draft_open() and not w.is_over() and w.tick < MAX_TICKS:
		w.step()


func _idx(w: SimWorld, id: String) -> int:
	for i: int in w.config.patches.size():
		if w.config.patches[i].id == id:
			return i
	return -1


func _max_out(w: SimWorld, ids: Array[String]) -> void:
	var picks: PackedInt32Array = w.patches.picks.duplicate()
	for id: String in ids:
		var i: int = _idx(w, id)
		picks[i] = w.config.patches[i].max_picks
	w.patches.set_picks(picks)


func _family(w: SimWorld, patch: int) -> String:
	return w.config.patches[patch].family


func test_every_draft_offers_arms_chassis_systems_in_that_order() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	for n: int in 300:
		var offers: PackedInt32Array = DraftSystem.roll_offers(w)
		assert_int(offers.size()).is_equal(3)
		for slot: int in 3:
			assert_str(_family(w, offers[slot])).is_equal(DraftSystem.FAMILIES[slot])


func test_an_empty_family_is_filled_from_the_others() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	_max_out(w, ["patch_extraction", "patch_t_greed"])  # SYSTEMS has nothing left
	for n: int in 200:
		var offers: PackedInt32Array = DraftSystem.roll_offers(w)
		assert_int(offers.size()).is_equal(3)
		assert_bool(offers[0] != offers[1] and offers[1] != offers[2] and offers[0] != offers[2]).is_true()
		assert_str(_family(w, offers[0])).is_equal("arms")
		assert_str(_family(w, offers[1])).is_equal("chassis")
		assert_bool(w.patches.qty(offers[2]) < w.config.patches[offers[2]].max_picks).is_true()
		assert_str(w.config.patches[offers[2]].id).is_not_equal("patch_extraction")
		assert_str(w.config.patches[offers[2]].id).is_not_equal("patch_t_greed")


func test_no_eligible_patch_in_two_families_still_gives_three_cards_when_enough_remain() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	_max_out(w, ["patch_overcharge", "patch_rate", "patch_t_glass", "patch_extraction", "patch_t_greed"])
	for n: int in 100:
		var offers: PackedInt32Array = DraftSystem.roll_offers(w)
		assert_int(offers.size()).is_equal(3)  # plating, regen, ceramic (hardhide may replace one)


func test_gamble_share_zero_and_one() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	w.config.tuning.draft_mix_gamble = 0.0
	for n: int in 100:
		for o: int in DraftSystem.roll_offers(w):
			assert_bool(w.config.patches[o].is_gamble()).is_false()
	w.config.tuning.draft_mix_gamble = 1.0
	for n: int in 100:
		var offers: PackedInt32Array = DraftSystem.roll_offers(w)
		assert_int(offers.size()).is_equal(3)
		for slot: int in 3:
			assert_bool(w.config.patches[offers[slot]].is_gamble()).is_true()
			assert_str(_family(w, offers[slot])).is_equal(DraftSystem.FAMILIES[slot])  # each in its own family slot


func test_a_gamble_replaces_the_card_of_its_own_family_only() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	w.config.tuning.draft_mix_gamble = 1.0
	_max_out(w, ["patch_t_glass", "patch_t_greed"])  # only HARDHIDE (CHASSIS) is left as a gamble
	var hardhide: int = _idx(w, "patch_t_hardhide")
	for n: int in 100:
		var offers: PackedInt32Array = DraftSystem.roll_offers(w)
		assert_int(offers.size()).is_equal(3)
		assert_int(offers[1]).is_equal(hardhide)
		assert_bool(w.config.patches[offers[0]].is_gamble()).is_false()
		assert_bool(w.config.patches[offers[2]].is_gamble()).is_false()
		assert_str(_family(w, offers[0])).is_equal("arms")
		assert_str(_family(w, offers[2])).is_equal("systems")


func test_reroll_is_logged_limited_and_changes_the_cards() -> void:
	var w: SimWorld = SimWorld.new(_cfg(5))
	assert_bool(w.command_reroll()).is_false()  # no draft open
	assert_int(w.input_log.size()).is_equal(0)
	_to_draft(w)
	var first: PackedInt32Array = w.draft.offers.duplicate()
	var changed: bool = false
	assert_bool(w.command_reroll()).is_true()
	changed = w.draft.offers != first
	assert_int(w.draft.rerolls_used).is_equal(1)
	assert_int(w.draft.offers.size()).is_equal(3)
	assert_bool(w.command_reroll()).is_false()  # one reroll per draft
	assert_int(w.input_log.size()).is_equal(1)
	assert_int(w.input_log.kinds[0]).is_equal(InputLog.CMD_REROLL)
	assert_int(w.input_log.ticks[0]).is_equal(w.tick)
	var differ: int = 1 if changed else 0
	for s: int in range(6, 16):  # across seeds a reroll nearly always shows other cards
		var other: SimWorld = SimWorld.new(_cfg(s))
		_to_draft(other)
		var before: PackedInt32Array = other.draft.offers.duplicate()
		assert_bool(other.command_reroll()).is_true()
		if other.draft.offers != before:
			differ += 1
	assert_int(differ).is_greater(3)


func test_the_next_draft_gets_a_fresh_reroll() -> void:
	var w: SimWorld = SimWorld.new(_cfg(5))
	_to_draft(w)
	assert_bool(w.command_reroll()).is_true()
	assert_bool(w.command_pick(0)).is_true()
	assert_int(w.draft.rerolls_used).is_equal(0)  # closed
	_to_draft(w)
	assert_int(w.draft.wave).is_equal(10)
	assert_int(w.draft.rerolls_used).is_equal(0)
	assert_bool(w.command_reroll()).is_true()


func _run_with_reroll(cfg: SimConfig, reroll_first: bool, until_wave: int) -> SimWorld:
	var w: SimWorld = SimWorld.new(cfg)
	var seen: int = 0
	while not w.is_over() and w.wave < until_wave:
		if w.is_draft_open():
			if reroll_first and seen == 0:
				assert_bool(w.command_reroll()).is_true()
			seen += 1
			assert_bool(w.command_pick(1)).is_true()
		w.step()
	return w


func test_reroll_determinism_same_inputs_same_hash_and_it_matters() -> void:
	var a: SimWorld = _run_with_reroll(_cfg(7), true, 12)
	var b: SimWorld = _run_with_reroll(_cfg(7), true, 12)
	var plain: SimWorld = _run_with_reroll(_cfg(7), false, 12)
	assert_int(a.tick).is_equal(b.tick)
	assert_str(a.state_hash()).is_equal(b.state_hash())
	assert_str(a.state_hash()).is_not_equal(plain.state_hash())  # the reroll moved the stream and the picks
	assert_int(a.input_log.size()).is_equal(plain.input_log.size() + 1)


func test_a_run_with_a_reroll_replays_to_its_final_hash() -> void:
	var live: SimWorld = _run_with_reroll(_cfg(7), true, 12)
	var rec: RunRecord = RunRecord.from_world(live)
	assert_str(Replay.run(_cfg(99), rec, live.tick)).is_equal(rec.final_hash)
	var back: RunRecord = RunRecord.from_json(rec.to_json())
	assert_str(Replay.run(_cfg(99), back, live.tick)).is_equal(rec.final_hash)


func test_snapshot_behind_a_rerolled_draft_keeps_the_used_reroll() -> void:
	var w: SimWorld = SimWorld.new(_cfg(4))
	_to_draft(w)
	assert_bool(w.command_reroll()).is_true()
	var back: SimWorld = SimSnapshot.restore(_cfg(4), SimSnapshot.capture(w, 1))
	assert_object(back).is_not_null()
	assert_int(back.draft.rerolls_used).is_equal(1)
	assert_array(back.draft.offers).is_equal(w.draft.offers)
	assert_str(back.state_hash()).is_equal(w.state_hash())
	assert_bool(back.command_reroll()).is_false()
