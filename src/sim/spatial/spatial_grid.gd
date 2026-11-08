class_name SpatialGrid
extends RefCounted
## Uniform grid over the arena with intrusive linked lists (TECH_ARCHITECTURE 2.5).
##
## `rebuild` is O(n) and runs once per tick after movement. Positions outside
## the arena are clamped to border cells; that keeps every cell-distance bound
## a true lower bound for query points inside the arena (queries from the
## origin, the only use in M1). Enemies killed after `rebuild` stay in the
## lists, so every query skips entries whose `alive` flag is 0.

var cells_per_side: int
var cell_size: float
var arena_radius: float

## First enemy index of each cell, -1 when empty.
var cell_head: PackedInt32Array
## Next enemy index in the same cell, -1 at the end of the list.
var next_in_cell: PackedInt32Array

var _inv_cell: float


func _init(arena_radius_m: float, cell_size_m: float) -> void:
	arena_radius = arena_radius_m
	cell_size = cell_size_m
	_inv_cell = 1.0 / cell_size_m
	cells_per_side = ceili(2.0 * arena_radius_m / cell_size_m)
	cell_head = PackedInt32Array()
	if cell_head.resize(cells_per_side * cells_per_side) != OK:
		push_error("SpatialGrid: resize failed")
	cell_head.fill(-1)
	next_in_cell = PackedInt32Array()


## Cell column or row for a coordinate, clamped to the grid.
func cell_coord(v: float) -> int:
	return clampi(floori((v + arena_radius) * _inv_cell), 0, cells_per_side - 1)


## Re-inserts every alive enemy and writes `store.cell[i]`. Allocates only if
## the store capacity changed since the last call (never in normal play).
func rebuild(store: EnemyStore) -> void:
	if next_in_cell.size() != store.capacity:
		if next_in_cell.resize(store.capacity) != OK:
			push_error("SpatialGrid: resize failed")
	cell_head.fill(-1)
	var n: int = cells_per_side
	var hw: int = store.high_water
	for i: int in range(hw):
		if store.alive[i] == 0:
			continue
		var c: int = cell_coord(store.pos_y[i]) * n + cell_coord(store.pos_x[i])
		store.cell[i] = c
		next_in_cell[i] = cell_head[c]
		cell_head[c] = i


## Nearest alive enemy to (x, y) within `max_range` (inclusive), ties broken by
## lowest `spawn_id`. Returns -1 if none. Scans cell rings outward and stops
## once the next ring cannot beat the best candidate.
func nearest(store: EnemyStore, x: float, y: float, max_range: float) -> int:
	var n: int = cells_per_side
	var cx0: int = cell_coord(x)
	var cy0: int = cell_coord(y)
	var best: int = -1
	var best_d2: float = max_range * max_range
	var best_sid: int = 0x7fffffff
	for k: int in range(n + 1):
		if k >= 1:
			var min_d: float = float(k - 1) * cell_size
			if min_d * min_d > best_d2:
				break
		for dy: int in range(-k, k + 1):
			var cy: int = cy0 + dy
			if cy < 0 or cy >= n:
				continue
			var step: int = 1 if (dy == k or dy == -k) else 2 * k
			var dx: int = -k
			while dx <= k:
				var cx: int = cx0 + dx
				dx += step
				if cx < 0 or cx >= n:
					continue
				var j: int = cell_head[cy * n + cx]
				while j != -1:
					if store.alive[j] != 0:
						var ex: float = store.pos_x[j] - x
						var ey: float = store.pos_y[j] - y
						var d2: float = ex * ex + ey * ey
						if d2 < best_d2 or (d2 == best_d2 and (best == -1 or store.spawn_id[j] < best_sid)):
							best_d2 = d2
							best = j
							best_sid = store.spawn_id[j]
					j = next_in_cell[j]
	return best


## Writes indices of alive enemies within `r` (inclusive) of (x, y) into the
## caller-owned `out` (never resized) and returns how many were written. If
## `out` is too small the result is truncated to `out.size()`. Order is
## unspecified but deterministic.
func query_radius(store: EnemyStore, x: float, y: float, r: float, out: PackedInt32Array) -> int:
	var n: int = cells_per_side
	var cx_lo: int = cell_coord(x - r)
	var cx_hi: int = cell_coord(x + r)
	var cy_lo: int = cell_coord(y - r)
	var cy_hi: int = cell_coord(y + r)
	var r2: float = r * r
	var count: int = 0
	var cap: int = out.size()
	for cy: int in range(cy_lo, cy_hi + 1):
		for cx: int in range(cx_lo, cx_hi + 1):
			var j: int = cell_head[cy * n + cx]
			while j != -1:
				if store.alive[j] != 0:
					var ex: float = store.pos_x[j] - x
					var ey: float = store.pos_y[j] - y
					if ex * ex + ey * ey <= r2:
						if count >= cap:
							return count
						out[count] = j
						count += 1
				j = next_in_cell[j]
	return count
