class_name TestDeterminism
extends GdUnitTestSuite
## Same (seed, config, no input) gives the same state hash; different seeds differ (M1-15 item 1).

const TICKS: int = 3000


func _hashes(seed_value: int) -> PackedStringArray:
	var cfg: SimConfig = SimConfigLoader.load_default(seed_value)
	cfg.debug_invulnerable = true  # keep the run alive so 3000 ticks exercise spawning and combat
	var w: SimWorld = SimWorld.new(cfg)
	var out: PackedStringArray = PackedStringArray()
	for t: int in range(1, TICKS + 1):
		w.step()
		if t == 100 or t == 1000 or t == TICKS:
			@warning_ignore("return_value_discarded")  # PackedStringArray.append returns a bool
			out.append(w.state_hash())
	return out


func test_same_seed_same_hash_at_checkpoints() -> void:
	var a: PackedStringArray = _hashes(1)
	var b: PackedStringArray = _hashes(1)
	assert_int(a.size()).is_equal(3)
	for i: int in 3:
		assert_str(a[i]).is_equal(b[i])
	assert_bool(a[0] != a[1] and a[1] != a[2]).is_true()


func test_different_seeds_differ() -> void:
	var a: PackedStringArray = _hashes(1)
	var b: PackedStringArray = _hashes(2)
	assert_str(a[2]).is_not_equal(b[2])
	assert_str(a[1]).is_not_equal(b[1])
