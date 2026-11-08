class_name MultiMeshBuffer
extends RefCounted
## Pure filler for MultiMesh instance buffers (TECH_ARCHITECTURE 2.6). No Node, no allocation:
## the caller owns `out` and sizes it to at least capacity * FLOATS_PER_INSTANCE.
##
## Layout per instance for MultiMesh.TRANSFORM_2D with use_colors (Godot 4.x docs,
## MultiMesh.buffer / RenderingServer.multimesh_set_buffer; verified by a test that compares
## Transform2D columns):
##   [0] basis.x.x  [1] basis.y.x  [2] 0  [3] origin.x     (row 0 of the 2x3 matrix, padded)
##   [4] basis.x.y  [5] basis.y.y  [6] 0  [7] origin.y     (row 1)
##   [8] r  [9] g  [10] b  [11] a                          (color)
## Meshes face +x, so basis.x = (cos a, sin a) * scale and basis.y = (-sin a, cos a) * scale.

const TRANSFORM_FLOATS: int = 8
const COLOR_FLOATS: int = 4
const FLOATS_PER_INSTANCE: int = TRANSFORM_FLOATS + COLOR_FLOATS


## Writes one instance at slot `n` of `out`. Position and scale are in pixels.
static func write_instance(
	out: PackedFloat32Array, n: int, px: float, py: float, angle: float, scale_px: float
) -> void:
	var o: int = n * FLOATS_PER_INSTANCE
	var c: float = cos(angle) * scale_px
	var s: float = sin(angle) * scale_px
	out[o] = c
	out[o + 1] = -s
	out[o + 2] = 0.0
	out[o + 3] = px
	out[o + 4] = s
	out[o + 5] = c
	out[o + 6] = 0.0
	out[o + 7] = py
	out[o + 8] = 1.0
	out[o + 9] = 1.0
	out[o + 10] = 1.0
	out[o + 11] = 1.0


## Fills `out` with the alive enemies of `type_index`: position lerp(prev, pos, alpha) in pixels
## (origin = Cinder, no axis flip), scale = radius * visual_scale in pixels, rotation facing the origin, white.
## `standoff` applies ViewMath.map_pos after interpolation; a non-empty `cull` rect (local px) skips
## instances whose center lies outside it (caller grows it by the largest sprite radius).
## Returns the instance count (also bounded by out capacity).
static func fill(
	store: EnemyStore,
	type_index: int,
	alpha: float,
	px_per_m: float,
	out: PackedFloat32Array,
	visual_scale: float = 1.0,
	standoff: bool = false,
	cull: Rect2 = Rect2()
) -> int:
	var cap: int = floori(out.size() / float(FLOATS_PER_INSTANCE))
	var n: int = 0
	for i: int in store.high_water:
		if store.alive[i] == 0 or store.type_id[i] != type_index:
			continue
		if n >= cap:
			break
		var mx: float = lerpf(store.prev_x[i], store.pos_x[i], alpha)
		var my: float = lerpf(store.prev_y[i], store.pos_y[i], alpha)
		var k: float = ViewMath.map_factor(mx, my, px_per_m) if standoff else px_per_m
		var x: float = mx * k
		var y: float = my * k
		if cull.has_area() and not cull.has_point(Vector2(x, y)):
			continue
		write_instance(out, n, x, y, atan2(-my, -mx), store.radius[i] * px_per_m * visual_scale)
		n += 1
	return n


## Fills `out` with alive bolts. ProjectileStore has no previous position, so the interpolated
## position is `pos - vel * dt * (1 - alpha)` (alpha 1 = current tick, alpha 0 = one tick back,
## exact for straight-line bolts). Rotation follows the velocity; scale = `radius_m * visual_scale`
## in pixels. `standoff` and `cull` as in fill().
static func fill_bolts(
	store: ProjectileStore,
	alpha: float,
	dt: float,
	px_per_m: float,
	radius_m: float,
	out: PackedFloat32Array,
	visual_scale: float = 1.0,
	standoff: bool = false,
	cull: Rect2 = Rect2()
) -> int:
	var cap: int = floori(out.size() / float(FLOATS_PER_INSTANCE))
	var back: float = dt * (1.0 - alpha)
	var n: int = 0
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		if n >= cap:
			break
		var vx: float = store.vel_x[i]
		var vy: float = store.vel_y[i]
		var mx: float = store.pos_x[i] - vx * back
		var my: float = store.pos_y[i] - vy * back
		var k: float = ViewMath.map_factor(mx, my, px_per_m) if standoff else px_per_m
		var x: float = mx * k
		var y: float = my * k
		if cull.has_area() and not cull.has_point(Vector2(x, y)):
			continue
		write_instance(out, n, x, y, atan2(vy, vx), radius_m * px_per_m * visual_scale)
		n += 1
	return n
