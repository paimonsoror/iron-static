class_name TestDraftScenario
extends GdUnitTestSuite
## R1-04 sim scenario: a whole invulnerable run through drafts at waves 5, 10, 15 and 20 with a reroll at the first
## draft. The drafts open on schedule with one card per family, the input log holds picks and the reroll, and the
## record replays to the same final hash (also after a JSON round trip).

const UNTIL_WAVE: int = 22


func _play(seed_value: int, reroll: bool, waves: PackedInt32Array) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(seed_value)
	cfg.debug_invulnerable = true
	var w: SimWorld = SimWorld.new(cfg)
	var first: bool = true
	while not w.is_over() and w.wave < UNTIL_WAVE:
		if w.is_draft_open():
			if reroll and first:
				assert_bool(w.command_reroll()).is_true()
			first = false
			var families: PackedStringArray = PackedStringArray()
			for o: int in w.draft.offers:
				families.append(w.config.patches[o].family)
			assert_array(families).is_equal(PackedStringArray(["arms", "chassis", "systems"]))
			assert_bool(waves.append(w.draft.wave)).is_false()
			assert_bool(w.command_pick(w.draft.wave % 3)).is_true()
		w.step()
	return w


func test_drafts_open_on_schedule_and_the_reroll_is_in_the_log() -> void:
	var waves: PackedInt32Array = PackedInt32Array()
	var w: SimWorld = _play(7, true, waves)
	assert_array(waves).is_equal(PackedInt32Array([5, 10, 15, 20]))
	assert_int(w.patches.total_picks).is_equal(4)
	var kinds: PackedInt32Array = PackedInt32Array()
	for k: int in w.input_log.size():
		assert_bool(kinds.append(w.input_log.kinds[k])).is_false()
	assert_array(kinds).is_equal(
		PackedInt32Array(
			[InputLog.CMD_REROLL, InputLog.CMD_PICK, InputLog.CMD_PICK, InputLog.CMD_PICK, InputLog.CMD_PICK]
		)
	)


func test_the_run_with_a_reroll_replays_to_its_final_hash() -> void:
	var w: SimWorld = _play(7, true, PackedInt32Array())
	var rec: RunRecord = RunRecord.from_world(w)
	var cfg: SimConfig = SimConfigLoader.load_default(99)
	cfg.debug_invulnerable = true
	assert_str(Replay.run(cfg, rec, w.tick)).is_equal(rec.final_hash)
	var back: RunRecord = RunRecord.from_json(rec.to_json())
	var cfg2: SimConfig = SimConfigLoader.load_default(99)
	cfg2.debug_invulnerable = true
	assert_str(Replay.run(cfg2, back, w.tick)).is_equal(rec.final_hash)


func test_the_same_seed_and_inputs_give_the_same_hash_and_a_reroll_changes_it() -> void:
	var a: SimWorld = _play(7, true, PackedInt32Array())
	var b: SimWorld = _play(7, true, PackedInt32Array())
	var c: SimWorld = _play(7, false, PackedInt32Array())
	assert_str(a.state_hash()).is_equal(b.state_hash())
	assert_str(a.state_hash()).is_not_equal(c.state_hash())
