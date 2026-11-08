class_name TestFrameReplay
extends GdUnitTestSuite
## Frame runs in the run record and replay (M3-22).

const MAX_TICKS: int = 60000


func _play(cfg: SimConfig) -> SimWorld:
	var w: SimWorld = SimWorld.new(cfg)
	while not w.is_over() and w.tick < MAX_TICKS:
		if w.tick % 45 == 0:
			@warning_ignore("return_value_discarded")
			w.command_buy(floori(float(w.tick) / 45.0) % 4, 1)
		w.step()
	return w


func _check(frame_id: String, mods: FrameMods) -> void:
	var live: SimWorld = _play(TestFrameMods.cfg_with(frame_id, mods))
	assert_bool(live.is_over()).is_true()
	var rec: RunRecord = RunRecord.from_world(live)
	assert_str(rec.frame_id).is_equal(frame_id)
	var back: RunRecord = RunRecord.from_json(rec.to_json())
	assert_object(back).is_not_null()
	assert_str(back.frame_id).is_equal(frame_id)
	assert_str(back.to_json()).is_equal(rec.to_json())
	var cfg: SimConfig = TestFrameMods.cfg_with(frame_id, mods, 99)
	assert_str(Replay.run(cfg, back, MAX_TICKS)).is_equal(rec.final_hash)
	assert_str(ConfigHash.compute(cfg)).is_equal(rec.config_hash)


func test_bulwark_run_replays() -> void:
	_check("bulwark", TestFrameMods.bulwark())


func test_striker_run_replays() -> void:
	_check("striker", TestFrameMods.striker())


func test_old_record_without_frame_replays_as_vanguard() -> void:
	var live: SimWorld = _play(SimConfigLoader.load_default(3))
	var rec: RunRecord = RunRecord.from_world(live)
	assert_str(rec.frame_id).is_equal("vanguard")
	assert_bool(rec.to_json().contains('"frame"')).is_false()
	var back: RunRecord = RunRecord.from_json(rec.to_json())
	# Even a config that still carries another frame replays as VANGUARD (record wins).
	var cfg: SimConfig = TestFrameMods.cfg_with("striker", TestFrameMods.striker(), 99)
	assert_str(Replay.run(cfg, back, MAX_TICKS)).is_equal(rec.final_hash)
