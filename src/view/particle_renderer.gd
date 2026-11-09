class_name ParticleRenderer
extends Node2D
## Draws the particle ring (V1-13, art bible 6.3): two MultiMeshInstance2D (additive + alpha smoke = 2 draw calls)
## over one `fx_sheet` texture, fixed capacity = the quality tier's `particle_cap` (smoke gets 1/8 of it).
## GPU-side integration: the vertex shader moves, spins, scales and fades every particle from its spawn data and
## `u_now` (sim seconds), so per frame the CPU only sets one uniform per material and re-uploads a buffer when a
## particle was written. Per-particle data travels in a float32 texture, not in instance COLOR/CUSTOM (V1-26).
## Local space: origin = Cinder (put this node at Cinder's screen position, like Enemies).
## The two ParticlePools are the write targets of FxEmitter; this node never reads the sim.

const SHADER_PATH: String = "res://assets/shaders/particle_ring.gdshader"
const SMOKE_FRACTION: int = 8
const MIN_SMOKE: int = 8
## Additive pool (flash, rings, sparks, shards, embers) and the alpha pool (smoke).
var additive := ParticlePool.new()
var smoke := ParticlePool.new()
## Test hook: counts setup() calls that allocated buffers; time and flush never change it.
var setup_count: int = 0
## Test hook: total slots cleared by the periodic sweep.
var sweep_cleared: int = 0

var _instances: Array[MultiMeshInstance2D] = []
var _mats: Array[ShaderMaterial] = []
var _pools: Array[ParticlePool] = []
var _data_tex: Array[ImageTexture] = []
var _now: float = 0.0
var _last_sweep: float = 0.0


## Builds the two MultiMeshes for a tier cap (total live particles). Safe to call again (rebuilds).
func setup(cap: int) -> void:
	for inst: MultiMeshInstance2D in _instances:
		inst.queue_free()
	_instances.clear()
	_mats.clear()
	_pools.clear()
	_data_tex.clear()
	var smoke_cap: int = maxi(floori(float(cap) / float(SMOKE_FRACTION)), MIN_SMOKE)
	var add_cap: int = maxi(cap - smoke_cap, MIN_SMOKE)
	additive.setup(add_cap)
	smoke.setup(smoke_cap)
	var base: Shader = load(SHADER_PATH) as Shader
	var mix_shader: Shader = make_mix_shader()
	var cells := PackedVector4Array()
	var kinds := PackedVector4Array()
	var kinds2 := PackedVector4Array()
	build_tables(cells, kinds, kinds2)
	var tex: Texture2D = ArtSlots.texture(ParticlePack.SLOTS[ParticlePack.KIND_FLASH])
	_add_layer(additive, base, tex, [cells, kinds, kinds2] as Array[PackedVector4Array])
	_add_layer(smoke, mix_shader, tex, [cells, kinds, kinds2] as Array[PackedVector4Array])
	setup_count += 1
	flush()


## Sim time in seconds; the shader derives every particle's age from it. Cheap (two uniforms).
func set_time(sim_seconds: float) -> void:
	_now = sim_seconds
	var wrapped: float = ParticlePack.clock_now(sim_seconds)
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter("u_now", wrapped)
	if sim_seconds - _last_sweep >= ParticlePack.SWEEP_S or sim_seconds < _last_sweep:
		_last_sweep = sim_seconds
		for pool: ParticlePool in _pools:
			var cleared: int = pool.sweep(sim_seconds)
			sweep_cleared += cleared


func now() -> float:
	return _now


## Uploads the pools that changed since the last flush (usually 0-1 uploads per frame).
func flush() -> void:
	for i: int in _pools.size():
		var pool: ParticlePool = _pools[i]
		var mm: MultiMesh = _instances[i].multimesh
		mm.visible_instance_count = pool.used
		if pool.dirty:
			RenderingServer.multimesh_set_buffer(mm.get_rid(), pool.buffer)
			_data_tex[i].update(data_image(pool))
			pool.dirty = false


## The alpha-blended twin of the particle shader (smoke pool): same code, `blend_mix` instead of `blend_add`.
## ShaderWarmup uses this too, so the warmed variant is the one the game draws.
static func make_mix_shader() -> Shader:
	var base: Shader = load(SHADER_PATH) as Shader
	var mix_shader := Shader.new()
	mix_shader.code = base.code.replace("render_mode blend_add;", "render_mode blend_mix;")
	return mix_shader


## The pool's per-particle data as a one-row RGBAH image (TEXELS texels per particle, half floats). Halves on
## purpose, see MultiMeshBuffer.data_image: the phone's driver has no float32 textures and Godot converted (and
## warned) on every upload. ParticlePack's precision budget is the fp16 worst case, so nothing visible changes.
static func data_image(pool: ParticlePool) -> Image:
	var img: Image = Image.create_from_data(
		pool.capacity * ParticlePack.TEXELS, 1, false, Image.FORMAT_RGBAF, pool.data.to_byte_array()
	)
	img.convert(Image.FORMAT_RGBAH)
	return img


## Empties both rings (new run or world change).
func clear() -> void:
	additive.clear()
	smoke.clear()
	flush()


## Live particles at the current sim time (both pools).
func live_count() -> int:
	return additive.live_count(_now) + smoke.live_count(_now)


func capacity_total() -> int:
	return additive.capacity + smoke.capacity


## Fills the shader tables: per kind the fx_sheet cell as uv (x, y, w, h), (aspect, fade-in, fade-out power, drag)
## and (spin amplitude, align to velocity).
static func build_tables(cells: PackedVector4Array, kinds: PackedVector4Array, kinds2: PackedVector4Array) -> void:
	var ok: bool = cells.resize(32) == OK and kinds.resize(32) == OK and kinds2.resize(32) == OK
	if not ok:
		push_error("ParticleRenderer: table resize failed")
	for k: int in 32:
		cells[k] = Vector4(0.0, 0.0, 0.0, 0.0)
		kinds[k] = Vector4(1.0, 0.0, 1.0, 0.0)
		kinds2[k] = Vector4(0.0, 0.0, 0.0, 0.0)
	for k: int in ParticlePack.KIND_COUNT:
		var art: ArtSlot = ArtSlots.slot(ParticlePack.SLOTS[k])
		var uv: Rect2 = art.frames_uv(0)
		var p := Vector4(1.0, 0.0, 1.0, 0.0)
		var p2 := Vector4(0.0, 0.0, 0.0, 0.0)
		if ParticlePack.is_spark(k):
			if art.valid:
				var crop: Rect2 = ParticlePack.SPARK_CROP
				var sheet := Vector2(art.sheet_size)
				uv = Rect2(uv.position + crop.position / sheet, crop.size / sheet)
			p = Vector4(0.25, 0.0, 1.0, 3.0)
			p2 = Vector4(0.0, 1.0, 0.0, 0.0)
		elif ParticlePack.is_smoke(k):
			p = Vector4(1.0, 0.15, 1.0, 0.5)
			p2 = Vector4(1.0, 0.0, 0.0, 0.0)
		elif ParticlePack.is_shard(k):
			p = Vector4(1.0, 0.0, 1.0, 1.5)
			p2 = Vector4(12.0, 0.0, 0.0, 0.0)
		elif ParticlePack.is_ember(k):
			p = Vector4(1.0, 0.1, 0.6, 0.0)
		elif k == ParticlePack.KIND_HALO:
			p = Vector4(1.0, 0.1, 1.0, 0.0)
		elif k == ParticlePack.KIND_FLASH:
			p = Vector4(1.0, 0.0, 1.5, 0.0)
		cells[k] = Vector4(uv.position.x, uv.position.y, uv.size.x, uv.size.y)
		kinds[k] = p
		kinds2[k] = p2


## `tables` = [u_cells, u_kind, u_kind2].
func _add_layer(pool: ParticlePool, shader: Shader, tex: Texture2D, tables: Array[PackedVector4Array]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.mesh = _unit_quad()
	mm.instance_count = pool.capacity
	mm.visible_instance_count = 0
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("u_cells", tables[0])
	mat.set_shader_parameter("u_kind", tables[1])
	mat.set_shader_parameter("u_kind2", tables[2])
	mat.set_shader_parameter("u_now", ParticlePack.clock_now(_now))
	var data_tex: ImageTexture = ImageTexture.create_from_image(data_image(pool))
	mat.set_shader_parameter("u_data", data_tex)
	var inst := MultiMeshInstance2D.new()
	inst.multimesh = mm
	inst.texture = tex
	inst.material = mat
	inst.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(inst)
	_instances.append(inst)
	_mats.append(mat)
	_pools.append(pool)
	_data_tex.append(data_tex)


static func _unit_quad() -> ArrayMesh:
	var arrays: Array = []
	if arrays.resize(Mesh.ARRAY_MAX) != OK:
		push_error("ParticleRenderer: quad arrays resize failed")
	var h: float = 0.5
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
