class_name TestStores
extends GdUnitTestSuite
## EnemyStore and ProjectileStore: capacity, free list, spawn ids, counters.

var _lcg: int = 12345


func _rand(n: int) -> int:
	# Tiny deterministic LCG (test-local; independent of Rng).
	_lcg = (_lcg * 6364136223846793005 + 1442695040888963407) & 0x7fffffffffffffff
	return (_lcg >> 33) % n


func test_enemy_full_returns_minus_one() -> void:
	var s: EnemyStore = EnemyStore.new(8)
	for k: int in range(8):
		assert_int(s.alloc(0)).is_equal(k)
	assert_int(s.alloc(0)).is_equal(-1)
	assert_int(s.alive_count).is_equal(8)
	assert_int(s.high_water).is_equal(8)


func test_enemy_default_capacity() -> void:
	var s: EnemyStore = EnemyStore.new()
	assert_int(s.capacity).is_equal(512)
	assert_int(s.alive.size()).is_equal(512)
	assert_int(s.hp.size()).is_equal(512)


func test_enemy_release_then_alloc_reuses_index() -> void:
	var s: EnemyStore = EnemyStore.new(8)
	for k: int in range(5):
		assert_int(s.alloc(0)).is_greater_equal(-1)
	s.release(2)
	assert_bool(s.is_alive(2)).is_false()
	assert_int(s.alloc(1)).is_equal(2)
	assert_bool(s.is_alive(2)).is_true()
	assert_int(s.high_water).is_equal(5)


func test_enemy_spawn_id_strictly_increases_across_reuse() -> void:
	var s: EnemyStore = EnemyStore.new(4)
	var last: int = -1
	for k: int in range(50):
		var i: int = s.alloc(0)
		if i == -1:
			s.release(k % 4)
			i = s.alloc(0)
		assert_int(i).is_greater_equal(0)
		assert_int(s.spawn_id[i]).is_greater(last)
		last = s.spawn_id[i]


func test_enemy_alloc_resets_fields() -> void:
	var s: EnemyStore = EnemyStore.new(4)
	var i: int = s.alloc(2)
	s.hp[i] = 99.0
	s.melee_hits[i] = 5
	s.stale[i] = 1
	s.next_attack_tick[i] = 77
	s.release(i)
	var j: int = s.alloc(3)
	assert_int(j).is_equal(i)
	assert_float(s.hp[j]).is_equal(0.0)
	assert_int(s.melee_hits[j]).is_equal(0)
	assert_int(s.stale[j]).is_equal(0)
	assert_int(s.next_attack_tick[j]).is_equal(0)
	assert_int(s.cell[j]).is_equal(-1)
	assert_int(s.type_id[j]).is_equal(3)


func test_enemy_double_release_is_noop() -> void:
	var s: EnemyStore = EnemyStore.new(4)
	var i: int = s.alloc(1)
	s.release(i)
	s.release(i)
	s.release(-1)
	s.release(99)
	assert_int(s.alive_count).is_equal(0)
	assert_int(s.count_type(1)).is_equal(0)
	var a: int = s.alloc(0)
	var b: int = s.alloc(0)
	assert_bool(a != b).is_true()


func test_enemy_random_sequence_matches_recount() -> void:
	var s: EnemyStore = EnemyStore.new(64)
	for _step: int in range(10000):
		if _rand(2) == 0:
			assert_int(s.alloc(_rand(5))).is_greater_equal(-1)
		else:
			s.release(_rand(64))
		assert_int(s.high_water).is_less_equal(s.capacity)
	var naive_alive: int = 0
	var naive_types: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0])
	for i: int in range(s.high_water):
		if s.alive[i] != 0:
			naive_alive += 1
			naive_types[s.type_id[i]] += 1
	assert_int(s.alive_count).is_equal(naive_alive)
	for t: int in range(5):
		assert_int(s.count_type(t)).is_equal(naive_types[t])


func test_enemy_counts_checked_every_step() -> void:
	var s: EnemyStore = EnemyStore.new(16)
	for _step: int in range(2000):
		if _rand(3) != 0:
			assert_int(s.alloc(_rand(5))).is_greater_equal(-1)
		else:
			s.release(_rand(16))
		var total: int = 0
		for t: int in range(5):
			total += s.count_type(t)
		assert_int(total).is_equal(s.alive_count)


func test_projectile_full_reuse_and_count() -> void:
	var p: ProjectileStore = ProjectileStore.new(4)
	for k: int in range(4):
		assert_int(p.alloc()).is_equal(k)
	assert_int(p.alloc()).is_equal(-1)
	p.damage[1] = 5.0
	p.release(1)
	assert_int(p.alive_count).is_equal(3)
	assert_int(p.alloc()).is_equal(1)
	assert_float(p.damage[1]).is_equal(0.0)
	assert_int(p.high_water).is_equal(4)


func test_projectile_random_sequence() -> void:
	var p: ProjectileStore = ProjectileStore.new(32)
	for _step: int in range(10000):
		if _rand(2) == 0:
			assert_int(p.alloc()).is_greater_equal(-1)
		else:
			p.release(_rand(32))
	var naive: int = 0
	for i: int in range(p.high_water):
		if p.alive[i] != 0:
			naive += 1
	assert_int(p.alive_count).is_equal(naive)
	assert_int(p.high_water).is_less_equal(32)
