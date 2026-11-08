class_name TestSpatialGrid
extends GdUnitTestSuite
## SpatialGrid vs brute force: nearest (with ties), query_radius, borders.

const ARENA: float = 52.0
const CELL: float = 4.0

var _lcg: int = 987654321


func _rand(n: int) -> int:
	_lcg = (_lcg * 6364136223846793005 + 1442695040888963407) & 0x7fffffffffffffff
	return (_lcg >> 33) % n


func _rf(lo: float, hi: float) -> float:
	return lo + (hi - lo) * float(_rand(1000000)) / 1000000.0


func _grid() -> SpatialGrid:
	return SpatialGrid.new(ARENA, CELL)


## Fills the store with `count` enemies. Spawn ids are scrambled relative to
## indices by churn (allocate extras, release random ones, reuse indices).
func _fill(s: EnemyStore, count: int, quantize: bool) -> void:
	var extra: int = 100
	for _k: int in range(count + extra):
		assert_int(s.alloc(0)).is_greater_equal(-1)
	for _k: int in range(extra * 3):
		s.release(_rand(count + extra))
	# Release survivors beyond `count`, then top up to exactly `count`.
	var i: int = 0
	while s.alive_count > count:
		s.release(i)
		i += 1
	while s.alive_count < count:
		assert_int(s.alloc(0)).is_greater_equal(-1)
	for k: int in range(s.high_water):
		if s.alive[k] == 0:
			continue
		var x: float = _rf(-ARENA, ARENA)
		var y: float = _rf(-ARENA, ARENA)
		if quantize:
			x = roundf(x / 2.0) * 2.0
			y = roundf(y / 2.0) * 2.0
		s.pos_x[k] = x
		s.pos_y[k] = y


func _brute_nearest(s: EnemyStore, x: float, y: float, rng: float) -> int:
	var best: int = -1
	var best_d2: float = rng * rng
	for i: int in range(s.high_water):
		if s.alive[i] == 0:
			continue
		var ex: float = s.pos_x[i] - x
		var ey: float = s.pos_y[i] - y
		var d2: float = ex * ex + ey * ey
		if d2 < best_d2 or (d2 == best_d2 and (best == -1 or s.spawn_id[i] < s.spawn_id[best])):
			best_d2 = d2
			best = i
	return best


func test_empty_store_returns_minus_one() -> void:
	var s: EnemyStore = EnemyStore.new(16)
	var g: SpatialGrid = _grid()
	g.rebuild(s)
	assert_int(g.nearest(s, 0.0, 0.0, 100.0)).is_equal(-1)
	var out: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	assert_int(g.query_radius(s, 0.0, 0.0, 100.0, out)).is_equal(0)


func test_fill_helper_gives_500_alive_with_scrambled_ids() -> void:
	var s: EnemyStore = EnemyStore.new(512)
	_fill(s, 500, false)
	assert_int(s.alive_count).is_equal(500)
	var inversions: int = 0
	var last_id: int = -1
	for i: int in range(s.high_water):
		if s.alive[i] != 0:
			if s.spawn_id[i] < last_id:
				inversions += 1
			last_id = s.spawn_id[i]
	assert_int(inversions).is_greater(0)


func test_nearest_matches_brute_force_random() -> void:
	var s: EnemyStore = EnemyStore.new(512)
	_fill(s, 500, false)
	var g: SpatialGrid = _grid()
	g.rebuild(s)
	for _q: int in range(1000):
		var x: float = _rf(-ARENA, ARENA)
		var y: float = _rf(-ARENA, ARENA)
		var r: float = _rf(1.0, 80.0)
		assert_int(g.nearest(s, x, y, r)).is_equal(_brute_nearest(s, x, y, r))


func test_nearest_matches_brute_force_with_ties() -> void:
	var s: EnemyStore = EnemyStore.new(512)
	_fill(s, 500, true)
	var g: SpatialGrid = _grid()
	g.rebuild(s)
	for _q: int in range(1000):
		var x: float = float(_rand(27) - 13) * 2.0
		var y: float = float(_rand(27) - 13) * 2.0
		var r: float = _rf(1.0, 60.0)
		assert_int(g.nearest(s, x, y, r)).is_equal(_brute_nearest(s, x, y, r))


func test_constructed_tie_prefers_lowest_spawn_id() -> void:
	var s: EnemyStore = EnemyStore.new(8)
	var a: int = s.alloc(0)
	var b: int = s.alloc(0)
	var c: int = s.alloc(0)
	s.pos_x[c] = -5.0
	s.pos_x[b] = 0.0
	s.pos_y[b] = 9.0
	s.release(a)
	var a2: int = s.alloc(0)  # reuses index a but has the highest spawn id
	s.pos_x[a2] = 5.0
	var g: SpatialGrid = _grid()
	g.rebuild(s)
	assert_int(a2).is_equal(a)
	assert_int(g.nearest(s, 0.0, 0.0, 20.0)).is_equal(c)


func test_range_is_inclusive_and_excludes_beyond() -> void:
	var s: EnemyStore = EnemyStore.new(4)
	var i: int = s.alloc(0)
	s.pos_x[i] = 10.0
	var g: SpatialGrid = _grid()
	g.rebuild(s)
	assert_int(g.nearest(s, 0.0, 0.0, 10.0)).is_equal(i)
	assert_int(g.nearest(s, 0.0, 0.0, 9.99)).is_equal(-1)


func test_query_radius_matches_brute_force() -> void:
	var s: EnemyStore = EnemyStore.new(512)
	_fill(s, 500, false)
	var g: SpatialGrid = _grid()
	g.rebuild(s)
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(out.resize(512)).is_equal(OK)
	for _q: int in range(300):
		var x: float = _rf(-ARENA, ARENA)
		var y: float = _rf(-ARENA, ARENA)
		var r: float = _rf(0.5, 30.0)
		var n: int = g.query_radius(s, x, y, r, out)
		var got: Array[int] = []
		for k: int in range(n):
			got.append(out[k])
		got.sort()
		var want: Array[int] = []
		for i: int in range(s.high_water):
			if s.alive[i] == 0:
				continue
			var ex: float = s.pos_x[i] - x
			var ey: float = s.pos_y[i] - y
			if ex * ex + ey * ey <= r * r:
				want.append(i)
		assert_array(got).is_equal(want)


func test_query_radius_truncates_to_buffer() -> void:
	var s: EnemyStore = EnemyStore.new(16)
	for _k: int in range(10):
		assert_int(s.alloc(0)).is_greater_equal(-1)
	var g: SpatialGrid = _grid()
	g.rebuild(s)
	var out: PackedInt32Array = PackedInt32Array([-1, -1, -1])
	assert_int(g.query_radius(s, 0.0, 0.0, 5.0, out)).is_equal(3)
	assert_int(out.size()).is_equal(3)


func test_cell_borders_and_outside_arena_found() -> void:
	var s: EnemyStore = EnemyStore.new(16)
	var pts: Array[Vector2] = [
		Vector2(4.0, 0.0),
		Vector2(-4.0, 0.0),
		Vector2(0.0, 48.0),
		Vector2(52.0, 0.0),
		Vector2(-52.0, -52.0),
		Vector2(60.0, 60.0),
		Vector2(0.0, -75.0),
	]
	var idx: Array[int] = []
	for p: Vector2 in pts:
		var i: int = s.alloc(0)
		s.pos_x[i] = p.x
		s.pos_y[i] = p.y
		idx.append(i)
	var g: SpatialGrid = _grid()
	g.rebuild(s)
	for k: int in range(idx.size()):
		var i: int = idx[k]
		assert_int(s.cell[i]).is_greater_equal(0)
		assert_int(s.cell[i]).is_less(g.cells_per_side * g.cells_per_side)
		assert_int(g.nearest(s, pts[k].x, pts[k].y, 0.5)).is_equal(i)
	assert_int(g.nearest(s, 0.0, 0.0, 200.0)).is_equal(idx[0])
	var out: PackedInt32Array = PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0])
	assert_int(g.query_radius(s, 0.0, 0.0, 200.0, out)).is_equal(7)


func test_killed_after_rebuild_is_skipped() -> void:
	var s: EnemyStore = EnemyStore.new(8)
	var a: int = s.alloc(0)
	var b: int = s.alloc(0)
	s.pos_x[a] = 3.0
	s.pos_x[b] = 6.0
	var g: SpatialGrid = _grid()
	g.rebuild(s)
	s.release(a)
	assert_int(g.nearest(s, 0.0, 0.0, 20.0)).is_equal(b)


func test_rebuild_timing_note() -> void:
	var s: EnemyStore = EnemyStore.new(512)
	_fill(s, 500, false)
	var g: SpatialGrid = _grid()
	g.rebuild(s)
	var t0: int = Time.get_ticks_usec()
	g.rebuild(s)
	var t1: int = Time.get_ticks_usec()
	assert_int(g.nearest(s, 0.0, 0.0, 30.0)).is_greater_equal(-1)
	var t2: int = Time.get_ticks_usec()
	print(
		(
			"[GRID TIMING] 500 enemies: rebuild %d us, 1 nearest query %d us (target < 1000 us total, informational)"
			% [t1 - t0, t2 - t1]
		)
	)
	assert_int(t2 - t0).is_greater_equal(0)
