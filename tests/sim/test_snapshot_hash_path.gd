class_name TestSnapshotHashPath
extends GdUnitTestSuite
## A restored world follows the identical hash path (M3-09 acceptance).

const FURTHER_TICKS: int = 3000
const CHECK_EVERY: int = 100


func _cfg(seed_value: int) -> SimConfig:
	var cfg: SimConfig = SimConfigLoader.load_default(seed_value)
	cfg.debug_invulnerable = true  # keep the run alive through the boss wave and the long tail
	return cfg


## Scripted buys, identical for both worlds (they depend only on the tick).
func _step(w: SimWorld) -> void:
	if w.tick % 45 == 0:
		@warning_ignore("return_value_discarded")
		w.command_buy(floori(float(w.tick) / 45.0) % 4, 1)
	w.step()


func _check(seed_value: int, capture_tick: int) -> void:
	var w: SimWorld = SimWorld.new(_cfg(seed_value))
	while w.tick < capture_tick:
		_step(w)
	var back: SimWorld = SimSnapshot.restore(_cfg(seed_value), SimSnapshot.capture(w, 1))
	assert_object(back).is_not_null()
	assert_str(back.state_hash()).is_equal(w.state_hash())
	var bad: int = 0
	for k: int in FURTHER_TICKS:
		_step(w)
		_step(back)
		if (k + 1) % CHECK_EVERY == 0 and back.state_hash() != w.state_hash():
			bad += 1
	assert_int(bad).is_equal(0)
	assert_str(back.state_hash()).is_equal(w.state_hash())
	assert_int(back.input_log.size()).is_equal(w.input_log.size())


func test_hash_path_matches_for_seeds_and_capture_ticks() -> void:
	var boss_tick: int = (SimConfigLoader.load_default(1).tuning.boss_interval - 1) * Ticks.WAVE_TICKS
	var ticks: PackedInt32Array = PackedInt32Array([0, 1, 719, 720, 1500, boss_tick])
	for seed_value: int in [1, 2, 3]:
		for t: int in ticks:
			_check(seed_value, t)


func _purge_cfg(seed_value: int) -> SimConfig:
	var cfg: SimConfig = _cfg(seed_value)
	assert_int(SimConfigLoader.apply_mode(cfg, "purge").size()).is_equal(0)
	return cfg


## M4-05: a snapshot taken at a random tick of a PURGE run, restored and run to wave 12, ends on the same hash.
func test_purge_snapshot_at_random_ticks_reaches_wave_12_on_the_same_hash() -> void:
	var rng: Rng = Rng.new(2026, 5)
	for seed_value: int in [1, 2]:
		var ticks: PackedInt32Array = PackedInt32Array()
		for k: int in 3:
			@warning_ignore("return_value_discarded")
			ticks.append(rng.range_int(1, 5000))
		for capture_tick: int in ticks:
			var w: SimWorld = SimWorld.new(_purge_cfg(seed_value))
			while w.tick < capture_tick:
				_step(w)
			var back: SimWorld = SimSnapshot.restore(_purge_cfg(seed_value), SimSnapshot.capture(w, 1))
			assert_object(back).is_not_null()
			assert_str(back.state_hash()).is_equal(w.state_hash())
			var guard: int = 0
			while w.wave < 12 and not w.is_over() and guard < 60000:
				_step(w)
				_step(back)
				guard += 1
			assert_int(w.wave).is_equal(12)
			assert_str(back.state_hash()).is_equal(w.state_hash())
