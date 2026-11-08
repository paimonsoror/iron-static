class_name TestFullRun
extends GdUnitTestSuite
## Default config, no upgrades, seed 1, played until Cinder dies (M1-15 item 3).

const MAX_TICKS: int = 60000
const DEATH_WAVE_MIN: int = 3
const DEATH_WAVE_MAX: int = 12


func _play(seed_value: int) -> SimWorld:
	var w: SimWorld = SimWorld.new(SimConfigLoader.load_default(seed_value))
	while not w.is_over() and w.tick < MAX_TICKS:
		w.step()
	return w


func test_seed_1_dies_in_gdd_window() -> void:
	var w: SimWorld = _play(1)
	assert_bool(w.is_over()).is_true()
	assert_int(w.tick).is_less(MAX_TICKS)
	assert_int(w.run.death_wave).is_between(DEATH_WAVE_MIN, DEATH_WAVE_MAX)
	assert_int(w.run.kills).is_greater(0)
	assert_bool(is_finite(w.run.scrap_earned) and is_finite(w.run.data_earned)).is_true()
	assert_bool(is_finite(w.run.damage_dealt) and is_finite(w.cinder.hp)).is_true()
	assert_float(w.run.scrap_earned).is_greater(0.0)


func test_hash_stable_across_two_executions() -> void:
	var a: SimWorld = _play(1)
	var b: SimWorld = _play(1)
	assert_str(a.state_hash()).is_equal(b.state_hash())
	assert_int(a.run.death_wave).is_equal(b.run.death_wave)


func test_other_seeds_also_end_with_finite_rewards() -> void:
	for s: int in [2, 3, 4]:
		var w: SimWorld = _play(s)
		assert_bool(w.is_over()).is_true()
		assert_bool(is_finite(w.run.scrap_earned) and is_finite(w.run.data_earned)).is_true()
