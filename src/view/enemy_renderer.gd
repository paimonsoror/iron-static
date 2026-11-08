class_name EnemyRenderer
extends Node2D
## Draws all enemies and bolts from the illustrated sheets: one MultiMeshInstance2D per type (5 enemy types +
## bolts = 6 draw calls, TECH_ARCHITECTURE 2.6) with the body + glow shader `enemy_sprite.gdshader`.
## Pure observer: reads the sim stores and events in render(). Local space: origin = Cinder, sim axes scaled by
## px_per_m (place this node at Cinder's screen position; any axis flip is the parent's job).
## Buffers are preallocated at setup(); render() only fills them and uploads once per type.
## Sprite size: quads are baked at pixel size from the slot table (`ArtSlot.sprite_scale()` x px_per_m / 33.75),
## so a skitter is 64 px wide and a walker about 112 px at 1080 width whatever the sim radius is.
## Per instance custom data (see MultiMeshBuffer): flash, flipbook frame, spawn-in, phase seed.

const SHADER_PATH: String = "res://assets/shaders/enemy_sprite.gdshader"
const ENEMY_SLOTS: Array[String] = ViewMath.ENEMY_SLOTS
const BOLT_SLOT: String = "bolt"
## Hit flash cap per type (art bible 6.2: heavy units 0.6; the others stay below 1.0 so a hit never turns the
## sprite into a white ghost, V1 gate review; impl).
const FLASH_CAP: Array[float] = [0.7, 0.7, 0.6, 0.7, 0.6]
## Re-upload the glow uniform only when it moved by at least this much.
const GLOW_EPS: float = 0.004
const DEFAULT_RADIUS_M: float = 0.5
const LANCER_TYPE: int = 3

## Visual options (quality tier, art bible 9.3); null = defaults (HIGH). Set by BattleView.
var visual: VisualSettings = null
## Test hook: counts every packed-array resize done by setup(); render() must never change it.
var resize_count: int = 0

var _px_per_m: float = ViewMath.REF_PPM
## Local-pixel rectangle outside which instance centers are skipped (empty = no culling).
var _cull := Rect2()
var _rids: Array[RID] = []  # index 0-4 enemy types, 5 bolts
var _buffers: Array[PackedFloat32Array] = []
var _instances: Array[MultiMeshInstance2D] = []
var _mats: Array[ShaderMaterial] = []
var _specs: Array[EnemyDrawSpec] = []
var _radius_px := PackedFloat32Array()
var _fx := EnemyFxState.new()
var _quality_fallback: VisualQuality = VisualQuality.high()
var _glow_applied: float = -1.0
var _glow: float = 1.0
var _bound_world_id: int = 0
var _last_now_s: float = -1.0


## `radii_m` (sim radius per type) is only the fallback size of a type whose slot has no body radius.
## `cinder_radius_m` sizes the per-type contact stand-off (sprite edge just outside Cinder's armor ring).
## The capacities size the preallocated buffers.
func setup(
	px_per_m: float,
	radii_m: PackedFloat32Array,
	enemy_capacity: int = EnemyStore.DEFAULT_CAPACITY,
	bolt_capacity: int = ProjectileStore.DEFAULT_CAPACITY,
	cinder_radius_m: float = 2.0
) -> void:
	_px_per_m = px_per_m
	for inst: MultiMeshInstance2D in _instances:
		inst.queue_free()
	_instances.clear()
	_rids.clear()
	_buffers.clear()
	_mats.clear()
	_specs.clear()
	var ok: bool = _radius_px.resize(ENEMY_SLOTS.size()) == OK
	var shader: Shader = load(SHADER_PATH) as Shader
	var kscale: float = px_per_m / ViewMath.REF_PPM
	for t: int in ENEMY_SLOTS.size() + 1:
		var is_bolt: bool = t == ENEMY_SLOTS.size()
		var slot_id: String = BOLT_SLOT if is_bolt else ENEMY_SLOTS[t]
		var art: ArtSlot = ArtSlots.slot(slot_id)
		var glow_art: ArtSlot = ArtSlots.glow_of(slot_id)
		var spec := EnemyDrawSpec.new()
		spec.scale_px = 1.0
		spec.frames = maxi(art.frames, glow_art.frames)
		spec.fps = art.fps
		if not is_bolt:
			_radius_px[t] = ViewMath.visual_radius_px(_radius_for(radii_m, t), t, px_per_m)
			spec.standoff_px = ViewMath.contact_standoff_px(_radius_px[t], cinder_radius_m, px_per_m)
			spec.fx = _fx
			if t == LANCER_TYPE:
				spec.fire_gap_ticks = 60  # replaced by the tuning value at bind
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.use_custom_data = true  # before instance_count
		mm.mesh = quad_mesh(art, art.sprite_scale() * kscale)
		var cap: int = bolt_capacity if is_bolt else enemy_capacity
		mm.instance_count = cap
		mm.visible_instance_count = 0
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter(
			"glow_tex", ArtSlots.texture(glow_art.id) if glow_art.valid else ArtSlots.placeholder()
		)
		mat.set_shader_parameter("body_frames", art.frames)
		mat.set_shader_parameter("glow_frames", glow_art.frames if art.frames == 1 and glow_art.valid else 1)
		mat.set_shader_parameter("flash_cap", 0.0 if is_bolt else FLASH_CAP[t])
		var inst := MultiMeshInstance2D.new()
		inst.multimesh = mm
		inst.texture = ArtSlots.texture(slot_id)
		inst.material = mat
		inst.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(inst)
		_instances.append(inst)
		_mats.append(mat)
		_specs.append(spec)
		_rids.append(mm.get_rid())
		var buf := PackedFloat32Array()
		ok = ok and buf.resize(cap * MultiMeshBuffer.FLOATS_PER_INSTANCE) == OK
		resize_count += 1
		_buffers.append(buf)
	if not ok:
		push_error("EnemyRenderer: buffer resize failed")
	_glow_applied = -1.0
	_bound_world_id = 0


## Fills and uploads every buffer. `alpha` = accumulator / SimWorld.DT in [0, 1].
func render(world: SimWorld, alpha: float) -> void:
	if _instances.is_empty():
		return
	var a: float = clampf(alpha, 0.0, 1.0)
	var store: EnemyStore = world.enemies
	_update_fx(world)
	var sim_t: float = (float(world.tick) + a) * SimWorld.DT
	_apply_glow(store.alive_count)
	for t: int in ENEMY_SLOTS.size():
		var spec: EnemyDrawSpec = _specs[t]
		spec.time_s = sim_t
		spec.tick_f = float(world.tick) + a
		var n: int = MultiMeshBuffer.fill(store, t, a, _px_per_m, _buffers[t], 1.0, true, _cull, spec)
		_upload(t, n)
	var last: int = ENEMY_SLOTS.size()
	var bspec: EnemyDrawSpec = _specs[last]
	bspec.time_s = sim_t
	var nb: int = MultiMeshBuffer.fill_bolts(
		world.projectiles, a, SimWorld.DT, _px_per_m, 0.0, _buffers[last], 1.0, true, _cull, bspec
	)
	_upload(last, nb)


func _update_fx(world: SimWorld) -> void:
	var id: int = world.get_instance_id()
	if id != _bound_world_id:
		_bound_world_id = id
		_fx.bind(world.events, world.enemies.capacity)
		_specs[LANCER_TYPE].fire_gap_ticks = maxi(Ticks.from_seconds(world.config.tuning.lancer_fire_s), 1)
		_last_now_s = -1.0
	var now_s: float = Time.get_ticks_msec() / 1000.0
	var dt: float = 0.0 if _last_now_s < 0.0 else clampf(now_s - _last_now_s, 0.0, 0.1)
	_last_now_s = now_s
	_fx.advance(dt, world.enemies.high_water)
	_fx.consume(world.events)  # after advance: a new hit starts at full strength this frame


func _apply_glow(alive: int) -> void:
	var q: VisualQuality = _quality_fallback
	if visual != null and visual.quality != null:
		q = visual.quality
	_glow = q.glow_strength(alive)
	if absf(_glow - _glow_applied) < GLOW_EPS and not (_glow == 0.0 and _glow_applied != 0.0):
		return
	_glow_applied = _glow
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter("glow_strength", _glow)


func _upload(slot: int, count: int) -> void:
	_instances[slot].multimesh.visible_instance_count = count
	RenderingServer.multimesh_set_buffer(_rids[slot], _buffers[slot])


## Pixel-sized quad of one cell of `art`, the pivot texel at the origin, facing +x; `px_per_texel` on-screen px.
static func quad_mesh(art: ArtSlot, px_per_texel: float) -> ArrayMesh:
	var cell := Vector2(art.cell_size)
	if not art.valid or cell.x <= 0.0:
		cell = Vector2(64.0, 64.0)
	var p: Vector2 = art.pivot if art.valid else cell * 0.5
	var x0: float = -p.x * px_per_texel
	var y0: float = -p.y * px_per_texel
	var x1: float = x0 + cell.x * px_per_texel
	var y1: float = y0 + cell.y * px_per_texel
	var arrays: Array = []
	if arrays.resize(Mesh.ARRAY_MAX) != OK:
		push_error("EnemyRenderer: quad arrays resize failed")
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Sets the culling rectangle in local pixels (Rect2() disables). Use `cull_rect_for`.
func set_cull(rect: Rect2) -> void:
	_cull = rect


## Battle rect (local px) grown by the largest sprite radius so nothing pops at the edge.
static func cull_rect_for(battle_rect_local: Rect2, px_per_m: float) -> Rect2:
	var margin: float = 4.0 * px_per_m * ViewMath.VISUAL_SCALE
	return battle_rect_local.grow(margin)


## Contact stand-off (px) used for enemies of `type_index` (feed it to ViewMath.map_dist / BeamRenderer).
func standoff_px(type_index: int) -> float:
	if type_index < 0 or type_index >= ENEMY_SLOTS.size() or _specs.is_empty():
		return ViewMath.STANDOFF_PX
	return _specs[type_index].standoff_px


## On-screen sprite radius (px) of an enemy type.
func sprite_radius_px(type_index: int) -> float:
	if type_index < 0 or type_index >= _radius_px.size():
		return 0.0
	return _radius_px[type_index]


## Draw position in local px (origin Cinder) of enemy slot `index` interpolated by `alpha`; the same remap the
## sprite uses. For FX that must sit on an enemy (V1-12 bursts, V1-13 damage numbers).
func draw_pos(store: EnemyStore, index: int, alpha: float) -> Vector2:
	var t: int = store.type_id[index]
	var mx: float = lerpf(store.prev_x[index], store.pos_x[index], alpha)
	var my: float = lerpf(store.prev_y[index], store.pos_y[index], alpha)
	return ViewMath.map_pos(Vector2(mx, my), _px_per_m, standoff_px(t))


## Current hit flash 0..1 of an enemy slot (before the per-type cap).
func flash_at(index: int) -> float:
	return _fx.flash_at(index)


## Glow multiplier applied to every sheet this frame (density ramp, 0 when the tier disables glow sheets).
func glow_strength() -> float:
	return _glow


## Events lost by this renderer's cursor (0 unless the view fell behind the ring).
func events_lost_total() -> int:
	return _fx.events_lost_total()


static func _radius_for(radii_m: PackedFloat32Array, t: int) -> float:
	return radii_m[t] if t < radii_m.size() else DEFAULT_RADIUS_M
