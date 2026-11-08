class_name TestExposureSystem
extends GdUnitTestSuite
## ExposureSystem: bands with hysteresis, regeneration, run end.


func _world(invulnerable: bool = false) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.debug_invulnerable = invulnerable
	var w: SimWorld = SimWorld.new(cfg)
	w.stats.nano_repair = 0.0
	return w


func _count(w: SimWorld, kind: int) -> int:
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(out.resize(SimEvents.CAPACITY * SimEvents.FIELDS)).is_equal(OK)
	var n: int = w.events.drain(0, out)
	var c: int = 0
	for k: int in n:
		if out[k * SimEvents.FIELDS + 1] == kind:
			c += 1
	return c


func _feed(w: SimWorld, fractions: Array[float]) -> PackedInt32Array:
	var bands: PackedInt32Array = PackedInt32Array()
	for f: float in fractions:
		w.cinder.hp = f * w.cinder.max_hp
		ExposureSystem.step(w)
		bands.append(w.cinder.band)
	return bands


func test_falling_then_rising_with_hysteresis() -> void:
	var w: SimWorld = _world()
	var bands: PackedInt32Array = _feed(w, [1.0, 0.74, 0.78, 0.81])
	assert_array(bands).is_equal(PackedInt32Array([0, 1, 1, 0]))


func test_band_boundaries_enter_at_or_below_threshold() -> void:
	var w: SimWorld = _world()
	var bands: PackedInt32Array = _feed(w, [0.76, 0.75, 0.51, 0.5, 0.26, 0.25])
	assert_array(bands).is_equal(PackedInt32Array([0, 1, 1, 2, 2, 3]))


func test_flicker_around_half_changes_at_most_twice() -> void:
	var w: SimWorld = _world()
	assert_int(_feed(w, [0.6]).size()).is_greater(0)
	var before: int = _count(w, SimEventKind.BAND_CHANGED)
	var bands: PackedInt32Array = _feed(w, [0.51, 0.49, 0.51, 0.49, 0.53, 0.56])
	assert_array(bands).is_equal(PackedInt32Array([1, 2, 2, 2, 2, 1]))
	assert_int(_count(w, SimEventKind.BAND_CHANGED) - before).is_less_equal(2)


func test_band_changed_event_payload() -> void:
	var w: SimWorld = _world()
	assert_int(_feed(w, [0.3, 0.2]).size()).is_greater(0)
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(out.resize(SimEvents.CAPACITY * SimEvents.FIELDS)).is_equal(OK)
	var n: int = w.events.drain(0, out)
	var seen: Array[Vector2i] = []
	for k: int in n:
		if out[k * SimEvents.FIELDS + 1] == SimEventKind.BAND_CHANGED:
			seen.append(Vector2i(out[k * SimEvents.FIELDS + 2], out[k * SimEvents.FIELDS + 3]))
	assert_array(seen).is_equal([Vector2i(0, 2), Vector2i(2, 3)])


func test_regeneration_restores_hp_over_30_ticks() -> void:
	var w: SimWorld = _world()
	w.stats.nano_repair = 1.0
	w.cinder.hp = w.cinder.max_hp - 1.0
	for k: int in 30:
		ExposureSystem.step(w)
	assert_float(w.cinder.hp).is_equal_approx(w.cinder.max_hp, 0.0001)
	ExposureSystem.step(w)
	assert_float(w.cinder.hp).is_equal(w.cinder.max_hp)


func test_run_end_pushed_once_with_death_wave() -> void:
	var w: SimWorld = _world()
	w.wave = 7
	w.run.death_cause = 2
	w.cinder.hp = 0.0
	w.cinder.alive = false
	ExposureSystem.step(w)
	ExposureSystem.step(w)
	assert_bool(w.is_over()).is_true()
	assert_int(w.run.death_wave).is_equal(7)
	assert_int(_count(w, SimEventKind.RUN_ENDED)).is_equal(1)
	# the world's own death check afterwards must not push a second event
	w.end_run()
	assert_int(_count(w, SimEventKind.RUN_ENDED)).is_equal(1)


func test_dead_cinder_does_not_regenerate() -> void:
	var w: SimWorld = _world()
	w.stats.nano_repair = 5.0
	w.cinder.hp = 0.0
	w.cinder.alive = false
	ExposureSystem.step(w)
	assert_float(w.cinder.hp).is_equal(0.0)


func test_invulnerable_cinder_never_ends_run() -> void:
	var w: SimWorld = _world(true)
	w.cinder.hp = 0.0
	ExposureSystem.step(w)
	assert_bool(w.is_over()).is_false()
	assert_int(w.cinder.band).is_equal(3)


func test_bands_do_not_modify_stats() -> void:
	var w: SimWorld = _world()
	var before: Array[float] = [w.stats.laser_output, w.stats.cycle_rate, w.stats.plating_pct, w.stats.hull_integrity]
	assert_int(_feed(w, [0.1, 0.9]).size()).is_greater(0)
	var after: Array[float] = [w.stats.laser_output, w.stats.cycle_rate, w.stats.plating_pct, w.stats.hull_integrity]
	assert_array(after).is_equal(before)
