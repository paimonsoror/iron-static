class_name TestFxRecipes
extends GdUnitTestSuite
## Pure numbers of the particle effects (art bible 6.1, 6.4, 6.5).


func test_kill_burst_counts_match_the_bible() -> void:
	for t: int in 2:  # skitter, dart
		assert_int(FxRecipes.kill_total(t, 10, true)).is_between(10, 12)
	assert_int(FxRecipes.kill_total(3, 10, true)).is_between(10, 12)  # lancer
	assert_int(FxRecipes.kill_total(2, 10, true)).is_less_equal(22)  # walker
	assert_int(FxRecipes.kill_total(2, 10, true)).is_greater(12)
	assert_int(FxRecipes.kill_total(4, 10, true)).is_less_equal(120)  # boss
	assert_int(FxRecipes.kill_total(4, 10, true)).is_greater(60)


func test_impact_counts() -> void:
	assert_int(FxRecipes.impact_total(6, 10, false, true)).is_equal(9)
	assert_int(FxRecipes.impact_total(6, 10, true, true)).is_less_equal(20)
	assert_int(FxRecipes.impact_total(2, 10, false, false)).is_equal(4)  # LOW tier: flash, halo, 2 sparks


func test_lod_thins_sparks_and_drops_rings_and_smoke() -> void:
	assert_int(FxRecipes.lod_sparks(6, 60)).is_equal(6)
	assert_int(FxRecipes.lod_sparks(6, 120)).is_equal(3)
	assert_int(FxRecipes.lod_sparks(6, 160)).is_equal(2)
	assert_int(FxRecipes.lod_sparks(2, 160)).is_equal(2)
	assert_bool(FxRecipes.rings_allowed(100, true, false)).is_true()
	assert_bool(FxRecipes.rings_allowed(160, true, false)).is_false()
	assert_bool(FxRecipes.rings_allowed(10, false, false)).is_false()
	assert_bool(FxRecipes.rings_allowed(10, true, true)).is_false()
	assert_bool(FxRecipes.smoke_allowed(100)).is_true()
	assert_bool(FxRecipes.smoke_allowed(101)).is_false()
	assert_int(FxRecipes.kill_total(0, 160, false)).is_less(FxRecipes.kill_total(0, 10, true))


func test_ember_rate_by_band() -> void:
	assert_float(FxRecipes.ember_rate(0)).is_equal(0.0)
	assert_float(FxRecipes.ember_rate(1)).is_equal(3.0)
	assert_float(FxRecipes.ember_rate(2)).is_equal(8.0)
	assert_float(FxRecipes.ember_rate(3)).is_equal(14.0)
	assert_float(FxRecipes.ember_rate(9)).is_equal(14.0)


func test_budgets_shrink_with_the_tier() -> void:
	assert_int(FxRecipes.hit_budget(0)).is_greater(FxRecipes.hit_budget(2))
	assert_int(FxRecipes.kill_budget(0)).is_greater(FxRecipes.kill_budget(2))
	assert_int(FxRecipes.particle_budget(0)).is_greater(FxRecipes.particle_budget(2))


func test_band_wedges_cover_all_twelve_wedges() -> void:
	var seen := {}
	for b: int in range(1, 4):
		var wedges: Array = FxRecipes.BAND_WEDGES[b]
		for w: int in wedges.size():
			seen[wedges[w]] = true
	assert_int(seen.size()).is_equal(12)
