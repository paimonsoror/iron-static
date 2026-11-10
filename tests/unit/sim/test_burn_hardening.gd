class_name TestBurnHardening
extends GdUnitTestSuite
## R1-05: damage taken is multiplied by burn_dr_b1..3 in skin burn bands 1-3, after plating and before the hit cap.


func _world() -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	var w: SimWorld = SimWorld.new(cfg)
	w.stats.plating_pct = 0.0
	w.stats.plating_flat = 0.0
	w.cinder.max_hp = 1000.0
	w.cinder.hp = 1000.0
	return w


func _hit(w: SimWorld, band: int, raw: float) -> float:
	w.cinder.hp = w.cinder.max_hp
	w.cinder.band = band
	return w.cinder.apply_hit(raw, w.stats, w.config.tuning)


func test_each_band_scales_the_hit_by_its_data_row() -> void:
	var w: SimWorld = _world()
	var t: SimTuning = w.config.tuning
	assert_float(_hit(w, 0, 100.0)).is_equal_approx(100.0, 1.0e-9)
	assert_float(_hit(w, 1, 100.0)).is_equal_approx(100.0 * t.burn_dr_b1, 1.0e-9)
	assert_float(_hit(w, 2, 100.0)).is_equal_approx(100.0 * t.burn_dr_b2, 1.0e-9)
	assert_float(_hit(w, 3, 100.0)).is_equal_approx(100.0 * t.burn_dr_b3, 1.0e-9)


func test_data_rows_are_the_review_values() -> void:
	var t: SimTuning = _world().config.tuning
	assert_float(t.burn_dr_b1).is_equal(0.75)
	assert_float(t.burn_dr_b2).is_equal(0.55)
	assert_float(t.burn_dr_b3).is_equal(0.35)


func test_hardening_applies_after_plating() -> void:
	var w: SimWorld = _world()
	w.stats.plating_pct = 0.5
	w.stats.plating_flat = 10.0
	# 100 -> 50 (percent) -> 40 (flat) -> x0.55 in band 2 = 22.
	assert_float(_hit(w, 2, 100.0)).is_equal_approx(22.0, 1.0e-9)
	# The damage floor works on the plated hit first (5% of 20 = 1.0), the band multiplier comes after.
	w.stats.plating_flat = 1000.0
	assert_float(_hit(w, 3, 40.0)).is_equal_approx(0.05 * 20.0 * w.config.tuning.burn_dr_b3, 1.0e-9)


func test_hardening_applies_before_the_hit_cap() -> void:
	var w: SimWorld = _world()
	w.cinder.hit_cap_frac = 0.10  # cap 100 hp
	# 500 raw x0.35 = 175, capped to 100; the cap is not scaled by the band.
	assert_float(_hit(w, 3, 500.0)).is_equal_approx(100.0, 1.0e-9)
	# 200 raw x0.55 = 110, capped to 100; 120 raw x0.55 = 66 stays under the cap.
	assert_float(_hit(w, 2, 200.0)).is_equal_approx(100.0, 1.0e-9)
	assert_float(_hit(w, 2, 120.0)).is_equal_approx(66.0, 1.0e-9)


func test_returned_damage_is_what_hp_lost() -> void:
	var w: SimWorld = _world()
	w.cinder.band = 1
	var taken: float = w.cinder.apply_hit(200.0, w.stats, w.config.tuning)
	assert_float(w.cinder.hp).is_equal_approx(1000.0 - taken, 1.0e-9)


func test_band_damage_mult_helper() -> void:
	var t: SimTuning = _world().config.tuning
	assert_float(CinderState.band_damage_mult(0, t)).is_equal(1.0)
	assert_float(CinderState.band_damage_mult(2, t)).is_equal(t.burn_dr_b2)
