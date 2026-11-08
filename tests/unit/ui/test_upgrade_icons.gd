class_name TestUpgradeIcons
extends GdUnitTestSuite
## UpgradeIcons (id -> icon slot) and RingAnim (milestone ring window, curves, perimeter), V1-17.


func test_every_run_upgrade_maps_to_an_existing_slot() -> void:
	var defs: Array[RunUpgradeDef] = SimConfigLoader.load_default(1).upgrades
	assert_int(defs.size()).is_equal(10)
	for def: RunUpgradeDef in defs:
		var slot_id: String = UpgradeIcons.slot_for(def.id)
		assert_bool(ArtSlots.has(slot_id)).is_true()
		assert_str(slot_id).is_equal("icon_" + def.id)
		assert_bool(UpgradeIcons.is_known(def.id)).is_true()
		assert_that(UpgradeIcons.tint_for(def.id)).is_equal(Color.WHITE)


func test_unknown_id_falls_back_to_an_existing_dim_icon() -> void:
	assert_str(UpgradeIcons.slot_for("no_such_upgrade")).is_equal(UpgradeIcons.FALLBACK_SLOT)
	assert_bool(ArtSlots.has(UpgradeIcons.FALLBACK_SLOT)).is_true()
	assert_float(UpgradeIcons.tint_for("no_such_upgrade").a).is_less(1.0)


func test_ring_window_table() -> void:
	var expected: Dictionary[int, bool] = {
		0: false,
		1: false,
		21: false,
		22: true,
		23: true,
		24: true,
		25: false,
		26: false,
		46: false,
		47: true,
		49: true,
		50: false
	}
	for lvl: int in expected:
		assert_bool(RingAnim.ring_for_level(lvl)).is_equal(expected[lvl])


func test_ring_window_matches_the_row_model() -> void:
	var w := SimWorld.new(SimConfigLoader.load_default(1))
	for lvl: int in [0, 5, 22, 24, 25, 47, 49, 50]:
		w.run_levels[0] = lvl
		var p: UpgradePreview = UpgradeSystem.preview(w, 0, 1)
		var m: UpgradeRowModel = UpgradeRowModel.from_preview(p, p.affordable, p.level, w.config.upgrades[0])
		assert_bool(m.milestone_glow).is_equal(RingAnim.ring_for_level(lvl))
		assert_int(m.level).is_equal(lvl)


func test_curves_and_perimeter() -> void:
	assert_float(RingAnim.sweep(0.0)).is_equal(0.0)
	assert_float(RingAnim.sweep(1.0)).is_equal_approx(0.5, 0.0001)
	assert_float(RingAnim.sweep(2.5)).is_equal_approx(0.25, 0.0001)
	assert_float(RingAnim.pulse(0.0)).is_equal_approx(0.0, 0.0001)
	assert_float(RingAnim.pulse(RingAnim.PULSE_S * 0.5)).is_equal_approx(1.0, 0.0001)
	assert_float(RingAnim.expand_progress(0.2)).is_equal_approx(0.5, 0.0001)
	assert_float(RingAnim.expand_progress(9.0)).is_equal(1.0)
	var size := Vector2(100.0, 50.0)
	assert_that(RingAnim.perimeter_point(size, 0.0)).is_equal(Vector2(0, 0))
	assert_that(RingAnim.perimeter_point(size, 100.0 / 300.0)).is_equal(Vector2(100, 0))
	assert_that(RingAnim.perimeter_point(size, 0.5)).is_equal(Vector2(100, 50))
	assert_that(RingAnim.perimeter_point(size, 1.0)).is_equal(Vector2(0, 0))
