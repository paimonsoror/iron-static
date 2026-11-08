class_name TestFoundryReplay
extends GdUnitTestSuite
## Foundry levels in the run record and replay (M3-07).

const MAX_TICKS: int = 60000


func _cfg(seed_value: int = 3) -> SimConfig:
	var cfg: SimConfig = SimConfigLoader.load_default(seed_value)
	_foundry(cfg)
	return cfg


func _foundry(cfg: SimConfig) -> void:
	var lv: PackedInt32Array = PackedInt32Array()
	var ff: PackedFloat64Array = PackedFloat64Array()
	if lv.resize(cfg.upgrades.size()) != OK or ff.resize(cfg.upgrades.size()) != OK:
		push_error("resize failed")
	lv.fill(0)
	ff.fill(0.0)
	for i: int in cfg.upgrades.size():
		match cfg.upgrades[i].id:
			"laser_output":
				lv[i] = 12
				ff[i] = 0.06
			"hull_integrity":
				lv[i] = 7
				ff[i] = 0.06
			"cycle_rate":
				lv[i] = 5
	cfg.foundry_levels = lv
	cfg.foundry_f = ff


func _play(cfg: SimConfig) -> SimWorld:
	var w: SimWorld = SimWorld.new(cfg)
	while not w.is_over() and w.tick < MAX_TICKS:
		if w.tick % 45 == 0:
			@warning_ignore("return_value_discarded")
			w.command_buy(floori(float(w.tick) / 45.0) % 4, 1)
		w.step()
	return w


func test_recorded_foundry_run_replays_to_the_same_hash() -> void:
	var live: SimWorld = _play(_cfg())
	assert_bool(live.is_over()).is_true()
	var rec: RunRecord = RunRecord.from_world(live)
	assert_str(rec.foundry).is_not_empty()
	var back: RunRecord = RunRecord.from_json(rec.to_json())
	assert_object(back).is_not_null()
	assert_str(back.foundry).is_equal(rec.foundry)
	assert_str(back.to_json()).is_equal(rec.to_json())
	# A config without the levels: the record restores them (factors f come from the caller's config).
	var cfg: SimConfig = SimConfigLoader.load_default(99)
	cfg.foundry_f = _cfg().foundry_f
	assert_str(Replay.run(cfg, back, MAX_TICKS)).is_equal(rec.final_hash)
	assert_str(ConfigHash.compute(cfg)).is_equal(rec.config_hash)


func test_record_is_id_keyed_and_only_nonzero() -> void:
	var rec: RunRecord = RunRecord.from_world(SimWorld.new(_cfg()))
	assert_str(rec.foundry).is_equal("laser_output:12;cycle_rate:5;hull_integrity:7")
	assert_str(rec.to_json()).contains('"foundry":"laser_output:12')


func test_record_without_foundry_key_still_replays_to_its_hash() -> void:
	var plain: SimWorld = _play(SimConfigLoader.load_default(3))
	var rec: RunRecord = RunRecord.from_world(plain)
	assert_str(rec.foundry).is_equal("")
	var json: String = rec.to_json()
	assert_bool(json.contains("foundry")).is_false()
	assert_bool(json.contains('"frame"')).is_false()
	var back: RunRecord = RunRecord.from_json(json)
	assert_str(Replay.run(SimConfigLoader.load_default(3), back, MAX_TICKS)).is_equal(rec.final_hash)
