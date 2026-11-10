class_name TestDraftSystem
extends GdUnitTestSuite
## Draft trigger, seeded offers, pick command, replay and snapshot while open (M4-15; schedule R1-04).

const MAX_TICKS: int = 60000
const WAVE_10_END_TICK: int = 10 * Ticks.WAVE_TICKS
const WAVE_5_END_TICK: int = 5 * Ticks.WAVE_TICKS


func _cfg(seed_value: int = 3, mode: String = "timed") -> SimConfig:
	var cfg: SimConfig = SimConfigLoader.load_default(seed_value)
	cfg.debug_invulnerable = true
	assert_int(SimConfigLoader.apply_mode(cfg, mode).size()).is_equal(0)
	return cfg


## Steps until a draft is open (or `limit` ticks pass).
func _to_draft(w: SimWorld, limit: int = MAX_TICKS) -> void:
	while not w.is_draft_open() and not w.is_over() and w.tick < limit:
		w.step()


## (a, b) of the newest event of `kind` among the last 8 pushed; Vector2i(-1, -1) if none.
func _last_event(w: SimWorld, kind: int) -> Vector2i:
	var ev: SimEvents = w.events
	for back: int in range(1, 9):
		if ev.total_pushed - back < 0:
			break
		var i: int = (ev.total_pushed - back) & (SimEvents.CAPACITY - 1)
		if ev.kind[i] == kind:
			return Vector2i(ev.a[i], ev.b[i])
	return Vector2i(-1, -1)


func test_schedule_matches_the_gdd() -> void:
	var t: SimTuning = SimConfigLoader.load_default(1).tuning
	var waves: PackedInt32Array = PackedInt32Array()
	for w: int in range(1, 201):
		if DraftSystem.is_draft_wave(t, w):
			waves.append(w)
	assert_array(waves).is_equal(PackedInt32Array([5, 10, 15, 20, 30, 40, 50, 75, 100, 125, 150, 175, 200]))
	assert_int(DraftSystem.waves_until(t, 10)).is_equal(0)
	assert_int(DraftSystem.waves_until(t, 7)).is_equal(3)
	assert_int(DraftSystem.waves_until(t, 51)).is_equal(24)


func test_timed_and_purge_open_the_first_draft_at_wave_5() -> void:
	for mode: String in ["timed", "purge"]:
		var w: SimWorld = SimWorld.new(_cfg(3, mode))
		_to_draft(w)
		assert_bool(w.is_draft_open()).is_true()
		assert_int(w.draft.wave).is_equal(5)
		assert_int(w.draft.offers.size()).is_equal(3)
		if mode == "timed":
			assert_int(w.tick).is_equal(WAVE_5_END_TICK)


func test_no_patch_defs_means_no_draft() -> void:
	var cfg: SimConfig = _cfg()
	cfg.patches.clear()
	var w: SimWorld = SimWorld.new(cfg)
	while w.tick < WAVE_10_END_TICK + 100:
		w.step()
	assert_bool(w.is_draft_open()).is_false()
	assert_int(w.wave).is_equal(11)


func test_open_draft_freezes_step_and_buys_until_a_pick() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	_to_draft(w)
	var before: String = w.state_hash()
	var tick: int = w.tick
	for i: int in 50:
		w.step()
	assert_int(w.tick).is_equal(tick)
	assert_str(w.state_hash()).is_equal(before)
	assert_int(w.command_buy(0, 1)).is_equal(0)
	assert_bool(w.command_pick(3)).is_false()  # no such slot
	assert_bool(w.command_pick(-1)).is_false()
	assert_int(w.input_log.size()).is_equal(0)
	var offered: int = w.draft.offers[1]
	assert_bool(w.command_pick(1)).is_true()
	assert_bool(w.is_draft_open()).is_false()
	assert_int(w.patches.qty(offered)).is_equal(1)
	assert_int(w.input_log.size()).is_equal(1)
	assert_int(w.input_log.kinds[0]).is_equal(InputLog.CMD_PICK)
	assert_int(w.input_log.arg_a[0]).is_equal(1)
	assert_int(w.input_log.ticks[0]).is_equal(tick)
	assert_bool(w.command_pick(0)).is_false()  # closed again
	w.step()
	assert_int(w.tick).is_equal(tick + 1)


func test_events_draft_opened_and_patch_picked() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	_to_draft(w)
	assert_object(_last_event(w, SimEventKind.DRAFT_OPENED)).is_equal(Vector2i(5, 3))
	var index: int = w.draft.offers[0]
	assert_bool(w.command_pick(0)).is_true()
	assert_object(_last_event(w, SimEventKind.PATCH_PICKED)).is_equal(Vector2i(index, 1))


func test_same_seed_same_offers_and_other_seeds_differ() -> void:
	var a: SimWorld = SimWorld.new(_cfg(11))
	var b: SimWorld = SimWorld.new(_cfg(11))
	_to_draft(a)
	_to_draft(b)
	assert_array(a.draft.offers).is_equal(b.draft.offers)
	var differ: int = 0
	for s: int in range(20, 30):
		var c: SimWorld = SimWorld.new(_cfg(s))
		_to_draft(c)
		if c.draft.offers != a.draft.offers:
			differ += 1
	assert_int(differ).is_greater(0)


func test_offers_are_distinct_and_never_include_a_maxed_patch() -> void:
	var w: SimWorld = SimWorld.new(_cfg(5))
	var maxed: int = 0
	var defs: Array[PatchDef] = w.config.patches
	var picks: PackedInt32Array = w.patches.picks.duplicate()
	for i: int in defs.size():
		if i % 2 == 0:
			picks[i] = defs[i].max_picks  # every other patch is at max
	w.patches.set_picks(picks)
	for n: int in 300:
		var offers: PackedInt32Array = DraftSystem.roll_offers(w)
		assert_int(offers.size()).is_equal(3)
		assert_bool(offers[0] != offers[1] and offers[0] != offers[2] and offers[1] != offers[2]).is_true()
		for o: int in offers:
			if w.patches.qty(o) >= defs[o].max_picks:
				maxed += 1
	assert_int(maxed).is_equal(0)


func test_fewer_eligible_patches_than_slots_shrinks_the_offer_and_none_means_no_draft() -> void:
	var w: SimWorld = SimWorld.new(_cfg(5))
	var defs: Array[PatchDef] = w.config.patches
	var picks: PackedInt32Array = PackedInt32Array()
	assert_int(picks.resize(defs.size())).is_equal(OK)
	for i: int in defs.size():
		picks[i] = defs[i].max_picks if i >= 2 else 0
	w.patches.set_picks(picks)
	assert_int(DraftSystem.roll_offers(w).size()).is_equal(2)
	picks[0] = defs[0].max_picks
	picks[1] = defs[1].max_picks
	w.patches.set_picks(picks)
	assert_int(DraftSystem.roll_offers(w).size()).is_equal(0)
	DraftSystem.check(w, 5)
	assert_bool(w.is_draft_open()).is_false()


func test_gamble_share_over_2000_drafts_is_15_percent() -> void:
	var w: SimWorld = SimWorld.new(_cfg(9))
	var gamble: int = 0
	var total: int = 0
	for n: int in 2000:
		for o: int in DraftSystem.roll_offers(w):
			total += 1
			if w.config.patches[o].is_gamble():
				gamble += 1
	var share: float = 100.0 * float(gamble) / float(total)
	assert_float(share).is_between(12.0, 18.0)  # 85/15 within 3 points (weapon share folded into standard)


func _run_with_picks(cfg: SimConfig, picks: PackedInt32Array, until_wave: int) -> SimWorld:
	var w: SimWorld = SimWorld.new(cfg)
	var done: int = 0
	while not w.is_over() and w.wave < until_wave:
		if w.is_draft_open():
			assert_bool(w.command_pick(picks[done % picks.size()])).is_true()
			done += 1
		w.step()
	return w


func test_a_run_with_two_picks_replays_to_its_final_hash() -> void:
	var live: SimWorld = _run_with_picks(_cfg(7), PackedInt32Array([1, 2]), 22)
	assert_int(live.patches.total_picks).is_equal(4)  # drafts at waves 5, 10, 15, 20
	assert_int(live.input_log.size()).is_equal(4)
	var rec: RunRecord = RunRecord.from_world(live)
	assert_int(rec.sim_version).is_equal(SimVersion.CURRENT)
	assert_str(Replay.run(_cfg(99), rec, live.tick)).is_equal(rec.final_hash)
	var back: RunRecord = RunRecord.from_json(rec.to_json())
	assert_int(back.commands.kinds[0]).is_equal(InputLog.CMD_PICK)
	assert_str(Replay.run(_cfg(99), back, live.tick)).is_equal(rec.final_hash)
	var checkpoints: PackedStringArray = Replay.checkpoints(_cfg(1), rec, PackedInt32Array([live.tick]))
	assert_str(checkpoints[0]).is_equal(rec.final_hash)


func test_replay_of_a_record_cut_inside_a_draft_stops() -> void:
	var live: SimWorld = SimWorld.new(_cfg(7))
	_to_draft(live)
	var rec: RunRecord = RunRecord.from_world(live)
	var w: SimWorld = Replay.run_world(_cfg(7), rec, MAX_TICKS)
	assert_bool(w.is_draft_open()).is_true()
	assert_str(w.state_hash()).is_equal(rec.final_hash)


func test_snapshot_taken_behind_an_open_draft_restores_it() -> void:
	var w: SimWorld = SimWorld.new(_cfg(4))
	_to_draft(w)
	var back: SimWorld = SimSnapshot.restore(_cfg(4), SimSnapshot.capture(w, 1))
	assert_object(back).is_not_null()
	assert_bool(back.is_draft_open()).is_true()
	assert_array(back.draft.offers).is_equal(w.draft.offers)
	assert_str(back.state_hash()).is_equal(w.state_hash())
	assert_bool(w.command_pick(2)).is_true()
	assert_bool(back.command_pick(2)).is_true()
	for k: int in 1500:
		w.step()
		back.step()
	assert_str(back.state_hash()).is_equal(w.state_hash())
	# A later snapshot carries the picks and the re-resolved stats.
	var again: SimWorld = SimSnapshot.restore(_cfg(4), SimSnapshot.capture(w, 1))
	assert_array(again.patches.picks).is_equal(w.patches.picks)
	assert_str(again.state_hash()).is_equal(w.state_hash())


func test_a_pick_changes_the_hash() -> void:
	var w: SimWorld = SimWorld.new(_cfg(6))
	_to_draft(w)
	var before: String = w.state_hash()
	assert_bool(w.command_pick(0)).is_true()
	assert_str(w.state_hash()).is_not_equal(before)
	assert_int(w.patches.total_picks).is_equal(1)


func test_config_hash_covers_patches_and_draft_tuning() -> void:
	var base: String = ConfigHash.compute(_cfg())
	var c1: SimConfig = _cfg()
	c1.tuning.draft_first_wave += 1
	assert_str(ConfigHash.compute(c1)).is_not_equal(base)
	var c2: SimConfig = _cfg()
	c2.patches[0].per_pick += 0.01
	assert_str(ConfigHash.compute(c2)).is_not_equal(base)
	var c3: SimConfig = _cfg()
	c3.patches.clear()
	assert_str(ConfigHash.compute(c3)).is_not_equal(base)
