class_name TestSimSnapshot
extends GdUnitTestSuite
## SimSnapshot capture/restore, header and the state-coverage guard (M3-09).


## Test subclass with one unclassified variable: the guard must flag exactly that name.
class DummyCinder:
	extends CinderState
	var unclassified_new_state: int = 0


func _cfg(seed_value: int = 3) -> SimConfig:
	return SimConfigLoader.load_default(seed_value)


func _run(w: SimWorld, ticks: int) -> void:
	var end: int = w.tick + ticks
	while w.tick < end and not w.is_over():
		if w.tick % 45 == 0:
			@warning_ignore("return_value_discarded")
			w.command_buy(floori(float(w.tick) / 45.0) % 4, 1)
		@warning_ignore("return_value_discarded")  # a draft takes the first offer (M4-15)
		PolicyBot.settle_draft(w)
		w.step()


func test_every_state_variable_is_classified() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	var checks: Dictionary = {
		"SimWorld": w,
		"CinderState": w.cinder,
		"RunStats": w.run,
		"EconomyState": w.economy,
		"WavePlanState": w.plan,
		"EnemyStore": w.enemies,
		"ProjectileStore": w.projectiles,
		"Rng": w.rng_spawn,
		"InputLog": w.input_log,
		"PatchState": w.patches,
		"DraftState": w.draft,
		"SpatialGrid": w.grid,
	}
	for key: String in checks:
		var obj: Object = checks[key]
		assert_array(SnapshotFields.unclassified(obj, key)).is_empty()
	for key: String in SnapshotFields.TABLE:
		assert_bool(checks.has(key)).is_true()


func test_guard_fails_on_a_new_unclassified_variable() -> void:
	var dummy: DummyCinder = DummyCinder.new()
	var missing: PackedStringArray = SnapshotFields.unclassified(dummy, "CinderState")
	assert_int(missing.size()).is_equal(1)
	assert_str(missing[0]).is_equal("unclassified_new_state")


func test_table_entries_name_a_real_variable() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	var checks: Dictionary = {"CinderState": w.cinder, "RunStats": w.run, "EconomyState": w.economy}
	for key: String in checks:
		var obj: Object = checks[key]
		var names: PackedStringArray = PackedStringArray()
		for p: Dictionary in obj.get_property_list():
			var usage: int = p["usage"]
			if usage & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
				var pn: String = p["name"]
				if names.append(pn):
					push_error("append failed")
		var entries: Dictionary = SnapshotFields.TABLE[key]
		for name_key: String in entries:
			assert_bool(names.has(name_key)).is_true()


func test_capture_restore_capture_is_byte_identical_and_hash_equal() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	_run(w, 1500)
	var bytes: PackedByteArray = SimSnapshot.capture(w, 7)
	var back: SimWorld = SimSnapshot.restore(_cfg(), bytes)
	assert_object(back).is_not_null()
	assert_str(back.state_hash()).is_equal(w.state_hash())
	assert_array(SimSnapshot.capture(back, 7)).is_equal(bytes)


func test_peek_reads_the_header() -> void:
	var w: SimWorld = SimWorld.new(_cfg(5))
	_run(w, 800)
	var info: SnapshotInfo = SimSnapshot.peek(SimSnapshot.capture(w, 12))
	assert_object(info).is_not_null()
	assert_int(info.seed_value).is_equal(5)
	assert_int(info.run_id).is_equal(12)
	assert_int(info.tick).is_equal(w.tick)
	assert_int(info.wave).is_equal(w.wave)
	assert_int(info.sim_version).is_equal(SimVersion.CURRENT)
	assert_str(info.config_hash).is_equal(ConfigHash.compute(_cfg(5)))
	assert_str(info.data_run).is_equal(w.economy.data_run.to_text())
	assert_str(info.frame_id).is_equal("vanguard")
	assert_int(SimSnapshot.capture(w).size()).is_greater(0)
	assert_object(SimSnapshot.peek(PackedByteArray())).is_null()
	assert_object(SimSnapshot.peek(var_to_bytes(5))).is_null()


func test_mismatched_version_or_config_returns_null() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	_run(w, 300)
	var bytes: PackedByteArray = SimSnapshot.capture(w)
	var other: SimConfig = _cfg()
	other.tuning.hp0 += 1.0
	assert_object(SimSnapshot.restore(other, bytes)).is_null()
	var d: Dictionary = bytes_to_var(bytes)
	d["sim_version"] = SimVersion.CURRENT + 1
	assert_object(SimSnapshot.restore(_cfg(), var_to_bytes(d))).is_null()
	assert_object(SimSnapshot.restore(_cfg(9), bytes)).is_null()  # other seed
	assert_object(SimSnapshot.restore(_cfg(), var_to_bytes({"format": 1}))).is_null()


func test_restored_input_log_keeps_recording_and_replays() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	_run(w, 1000)
	var back: SimWorld = SimSnapshot.restore(_cfg(), SimSnapshot.capture(w))
	assert_int(back.input_log.size()).is_equal(w.input_log.size())
	_run(w, 1500)
	_run(back, 1500)
	assert_int(back.input_log.size()).is_equal(w.input_log.size())
	assert_array(back.input_log.ticks).is_equal(w.input_log.ticks)
	var rec: RunRecord = RunRecord.from_world(back)
	assert_str(Replay.run(_cfg(99), rec, rec.final_tick)).is_equal(back.state_hash())


func test_foundry_and_frame_runs_restore() -> void:
	var cfg: SimConfig = TestFrameMods.cfg_with("striker", TestFrameMods.striker(), 4)
	var lv: PackedInt32Array = PackedInt32Array()
	var ff: PackedFloat64Array = PackedFloat64Array()
	if lv.resize(cfg.upgrades.size()) != OK or ff.resize(cfg.upgrades.size()) != OK:
		push_error("resize failed")
	lv.fill(0)
	ff.fill(0.0)
	lv[0] = 8
	ff[0] = 0.06
	cfg.foundry_levels = lv
	cfg.foundry_f = ff
	var w: SimWorld = SimWorld.new(cfg)
	_run(w, 1200)
	assert_int(w.overclock_kills).is_greater_equal(0)
	var back: SimWorld = SimSnapshot.restore(cfg, SimSnapshot.capture(w))
	assert_object(back).is_not_null()
	assert_int(back.overclock_kills).is_equal(w.overclock_kills)
	assert_float(back.stats.laser_output).is_equal(w.stats.laser_output)
	_run(w, 600)
	_run(back, 600)
	assert_str(back.state_hash()).is_equal(w.state_hash())
	# A snapshot of one frame never restores under another.
	assert_object(SimSnapshot.restore(_cfg(4), SimSnapshot.capture(w))).is_null()


func _purge_cfg(seed_value: int = 3) -> SimConfig:
	var cfg: SimConfig = _cfg(seed_value)
	assert_int(SimConfigLoader.apply_mode(cfg, "purge").size()).is_equal(0)
	return cfg


func test_peek_returns_the_wave_mode_and_restore_checks_it() -> void:
	var timed: SimWorld = SimWorld.new(_cfg())
	_run(timed, 300)
	assert_str(SimSnapshot.peek(SimSnapshot.capture(timed, 1)).wave_mode).is_equal("timed")
	var w: SimWorld = SimWorld.new(_purge_cfg())
	_run(w, 900)
	var bytes: PackedByteArray = SimSnapshot.capture(w, 4)
	assert_str(SimSnapshot.peek(bytes).wave_mode).is_equal("purge")
	var back: SimWorld = SimSnapshot.restore(_purge_cfg(), bytes)
	assert_object(back).is_not_null()
	assert_str(back.state_hash()).is_equal(w.state_hash())
	assert_array(SimSnapshot.capture(back, 4)).is_equal(bytes)
	assert_object(SimSnapshot.restore(_cfg(), bytes)).is_null()  # a timed config does not take a PURGE snapshot


func test_snapshot_without_a_mode_key_is_timed() -> void:
	var w: SimWorld = SimWorld.new(_cfg())
	_run(w, 300)
	var d: Dictionary = bytes_to_var(SimSnapshot.capture(w, 2))
	assert_bool(d.erase("mode")).is_true()
	var old: PackedByteArray = var_to_bytes(d)
	assert_str(SimSnapshot.peek(old).wave_mode).is_equal("timed")
	var back: SimWorld = SimSnapshot.restore(_cfg(), old)
	assert_object(back).is_not_null()
	assert_str(back.state_hash()).is_equal(w.state_hash())
