class_name MultiMeshBuffer
extends RefCounted
## Pure filler for MultiMesh instance buffers (TECH_ARCHITECTURE 2.6). No Node, no allocation:
## the caller owns `out` and `data` and sizes them to at least capacity * FLOATS_PER_INSTANCE / DATA_FLOATS.
##
## V1-29: the MultiMesh is TRANSFORM-ONLY (use_colors = false, use_custom_data = false). On the Pixel's PowerVR GPU
## via ANGLE the packed-half instance COLOR / CUSTOM attributes arrive as garbage once they change every frame, so
## the per-instance fields travel in a float32 data texture instead (same fix as the particle ring, V1-26).
##
## Transform buffer, 8 floats per instance (Godot 4.7, MultiMesh.buffer / RenderingServer.multimesh_set_buffer,
## verified against a real MultiMesh by tests/unit/view/test_multimesh_buffer.gd):
##   [0] basis.x.x  [1] basis.y.x  [2] 0  [3] origin.x     (row 0 of the 2x3 matrix, padded)
##   [4] basis.x.y  [5] basis.y.y  [6] 0  [7] origin.y     (row 1)
## Data buffer, DATA_FLOATS (4) floats per instance = ONE RGBAF texel of a one-row texture, texel x = INSTANCE_ID
## (enemy_sprite.gdshader reads it with texelFetch):
##   r flash 0..1   g flipbook frame (integer)   b spawn-in 0..1 (1 = spawned)   a phase seed for the glow pulse
## The instance colour is always white and no longer exists. Meshes face +x, so basis.x = (cos a, sin a) * scale
## and basis.y = (-sin a, cos a) * scale.

const TRANSFORM_FLOATS: int = 8
const FLOATS_PER_INSTANCE: int = TRANSFORM_FLOATS
const DATA_FLOATS: int = 4
const D_FLASH: int = 0
const D_FRAME: int = 1
const D_SPAWN: int = 2
const D_PHASE: int = 3
## Widest data texture (one texel per instance, one row). Real capacities are 512; GLES3 guarantees 2048 and the
## target GPUs 8192, so one row is enough and a larger capacity is clamped with an error (see `data_capacity`).
const MAX_TEX_WIDTH: int = 4096


## Texture width (instances) for a capacity: one texel per instance, clamped to MAX_TEX_WIDTH.
static func data_capacity(cap: int) -> int:
	if cap > MAX_TEX_WIDTH:
		push_error("MultiMeshBuffer: capacity %d exceeds the data texture width %d" % [cap, MAX_TEX_WIDTH])
	return clampi(cap, 1, MAX_TEX_WIDTH)


## The data buffer as a one-row RGBAF image (float32, exact), width = floats / DATA_FLOATS.
static func data_image(data: PackedFloat32Array) -> Image:
	return Image.create_from_data(
		floori(data.size() / float(DATA_FLOATS)), 1, false, Image.FORMAT_RGBAF, data.to_byte_array()
	)


## Writes one instance at slot `n`: transform into `out`, flash/frame/spawn/phase into `data`. Position and scale
## are in pixels. Defaults are no flash, frame 0, fully spawned, phase 0.
static func write_instance(
	out: PackedFloat32Array,
	data: PackedFloat32Array,
	n: int,
	px: float,
	py: float,
	angle: float,
	scale_px: float,
	flash: float = 0.0,
	frame: float = 0.0,
	spawn: float = 1.0,
	phase: float = 0.0
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
	var d: int = n * DATA_FLOATS
	data[d + D_FLASH] = flash
	data[d + D_FRAME] = frame
	data[d + D_SPAWN] = spawn
	data[d + D_PHASE] = phase


## Fills `out` with the alive enemies of `type_index`: position lerp(prev, pos, alpha) in pixels
## (origin = Cinder, no axis flip), scale = radius * visual_scale in pixels, rotation facing the origin, white.
## `standoff` applies ViewMath.map_pos after interpolation; a non-empty `cull` rect (local px) skips
## instances whose center lies outside it (caller grows it by the largest sprite radius).
## With a `spec` (textured renderer): scale and stand-off come from it and the data texel carries flash
## (spec.fx), flipbook frame, spawn-in and the phase seed.
## Returns the instance count (also bounded by out capacity).
static func fill(
	store: EnemyStore,
	type_index: int,
	alpha: float,
	px_per_m: float,
	out: PackedFloat32Array,
	data: PackedFloat32Array,
	visual_scale: float = 1.0,
	standoff: bool = false,
	cull: Rect2 = Rect2(),
	spec: EnemyDrawSpec = null
) -> int:
	var cap: int = _capacity(out, data)
	var n: int = 0
	var standoff_px: float = ViewMath.STANDOFF_PX if spec == null else spec.standoff_px
	for i: int in store.high_water:
		if store.alive[i] == 0 or store.type_id[i] != type_index:
			continue
		if n >= cap:
			break
		var mx: float = lerpf(store.prev_x[i], store.pos_x[i], alpha)
		var my: float = lerpf(store.prev_y[i], store.pos_y[i], alpha)
		var k: float = ViewMath.map_factor(mx, my, px_per_m, standoff_px) if standoff else px_per_m
		var x: float = mx * k
		var y: float = my * k
		if cull.has_area() and not cull.has_point(Vector2(x, y)):
			continue
		var angle: float = atan2(-my, -mx)
		if spec == null:
			write_instance(out, data, n, x, y, angle, store.radius[i] * px_per_m * visual_scale)
		else:
			_write_textured(out, data, n, x, y, angle, i, store, spec)
		n += 1
	return n


static func _write_textured(
	out: PackedFloat32Array,
	data: PackedFloat32Array,
	n: int,
	x: float,
	y: float,
	angle: float,
	i: int,
	store: EnemyStore,
	spec: EnemyDrawSpec
) -> void:
	var frame: int = 0
	if spec.fire_gap_ticks > 0:
		var since_ticks: float = spec.tick_f - float(store.next_attack_tick[i] - spec.fire_gap_ticks)
		frame = EnemyInstanceData.lancer_frame(since_ticks * SimWorld.DT)
	else:
		var phase: float = EnemyInstanceData.phase_for(i, spec.frames)
		frame = EnemyInstanceData.frame_for(spec.time_s, spec.fps, phase, spec.frames)
	var flash: float = 0.0
	var spawn: float = 1.0
	if spec.fx != null:
		flash = spec.fx.flash_at(i)
		spawn = spec.fx.spawn_at(i)
	write_instance(
		out, data, n, x, y, angle, spec.scale_px, flash, float(frame), spawn, EnemyInstanceData.pulse_seed(i)
	)


## Fills `out` with alive bolts. ProjectileStore has no previous position, so the interpolated
## position is `pos - vel * dt * (1 - alpha)` (alpha 1 = current tick, alpha 0 = one tick back,
## exact for straight-line bolts). Rotation follows the velocity; scale = `radius_m * visual_scale`
## in pixels. `standoff` and `cull` as in fill(). With a `spec` the scale is spec.scale_px, the stand-off
## spec.standoff_px and the flipbook frame goes to the data texel.
static func fill_bolts(
	store: ProjectileStore,
	alpha: float,
	dt: float,
	px_per_m: float,
	radius_m: float,
	out: PackedFloat32Array,
	data: PackedFloat32Array,
	visual_scale: float = 1.0,
	standoff: bool = false,
	cull: Rect2 = Rect2(),
	spec: EnemyDrawSpec = null
) -> int:
	var cap: int = _capacity(out, data)
	var back: float = dt * (1.0 - alpha)
	var n: int = 0
	var standoff_px: float = ViewMath.STANDOFF_PX if spec == null else spec.standoff_px
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		if n >= cap:
			break
		var vx: float = store.vel_x[i]
		var vy: float = store.vel_y[i]
		var mx: float = store.pos_x[i] - vx * back
		var my: float = store.pos_y[i] - vy * back
		var k: float = ViewMath.map_factor(mx, my, px_per_m, standoff_px) if standoff else px_per_m
		var x: float = mx * k
		var y: float = my * k
		if cull.has_area() and not cull.has_point(Vector2(x, y)):
			continue
		if spec == null:
			write_instance(out, data, n, x, y, atan2(vy, vx), radius_m * px_per_m * visual_scale)
		else:
			var phase: float = EnemyInstanceData.phase_for(i, spec.frames)
			var frame: int = EnemyInstanceData.frame_for(spec.time_s, spec.fps, phase, spec.frames)
			var pulse: float = EnemyInstanceData.pulse_seed(i)
			write_instance(out, data, n, x, y, atan2(vy, vx), spec.scale_px, 0.0, float(frame), 1.0, pulse)
		n += 1
	return n


static func _capacity(out: PackedFloat32Array, data: PackedFloat32Array) -> int:
	return mini(floori(out.size() / float(FLOATS_PER_INSTANCE)), floori(data.size() / float(DATA_FLOATS)))
