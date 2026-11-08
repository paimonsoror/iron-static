class_name TestRng
extends GdUnitTestSuite
## PCG32 Rng: reference vector, determinism, streams, state, range, chance.


func test_reference_vector_seed_42_seq_54() -> void:
	var r: Rng = Rng.new(42, 54)
	var expected: Array[int] = [0xa15c02b7, 0x7b47f409, 0xba1d3330, 0x83d2f293, 0xbfa4784b, 0xcbed606e]
	for e: int in expected:
		assert_int(r.next_u32()).is_equal(e)


func test_same_seed_same_sequence() -> void:
	var a: Rng = Rng.new(7, 3)
	var b: Rng = Rng.new(7, 3)
	var mismatches: int = 0
	for i: int in 10000:
		if a.next_u32() != b.next_u32():
			mismatches += 1
	assert_int(mismatches).is_equal(0)


func test_different_stream_names_differ() -> void:
	var a: Rng = Rng.derive(99, "spawn")
	var b: Rng = Rng.derive(99, "loot")
	var same: int = 0
	for i: int in 100:
		if a.next_u32() == b.next_u32():
			same += 1
	assert_int(same).is_less(3)
	var c: Rng = Rng.derive(99, "spawn")
	var d: Rng = Rng.derive(99, "spawn")
	assert_int(c.next_u32()).is_equal(d.next_u32())


func test_save_restore_state() -> void:
	var a: Rng = Rng.new(5)
	for i: int in 17:
		a.next_u32()
	var saved: PackedInt64Array = a.get_state()
	var expected: Array[int] = []
	for i: int in 50:
		expected.append(a.next_u32())
	var b: Rng = Rng.new(0)
	b.set_state(saved)
	for i: int in 50:
		assert_int(b.next_u32()).is_equal(expected[i])


func test_next_float_in_unit_interval() -> void:
	var r: Rng = Rng.new(11)
	var bad: int = 0
	for i: int in 10000:
		var f: float = r.next_float()
		if f < 0.0 or f >= 1.0:
			bad += 1
	assert_int(bad).is_equal(0)


func test_range_int_buckets_uniform() -> void:
	var r: Rng = Rng.new(2024)
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(10)
	for i: int in 100000:
		var v: int = r.range_int(0, 9)
		counts[v] += 1
	for c: int in counts:
		assert_int(c).is_between(9500, 10500)


func test_range_int_bounds() -> void:
	var r: Rng = Rng.new(3)
	for i: int in 1000:
		assert_int(r.range_int(-3, 4)).is_between(-3, 4)
	assert_int(r.range_int(5, 5)).is_equal(5)


func test_chance_extremes() -> void:
	var r: Rng = Rng.new(8)
	var never: int = 0
	var always: int = 0
	for i: int in 1000:
		if r.chance(0.0):
			never += 1
		if r.chance(1.0):
			always += 1
	assert_int(never).is_equal(0)
	assert_int(always).is_equal(1000)
