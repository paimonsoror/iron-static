class_name ShaderWarmup
extends Node2D
## Boot-time shader warm-up (V1-24). The Compatibility renderer compiles a shader variant the first time it is
## drawn, which hitches the first hit flash, particle burst or boss. This node draws each game material once
## (MultiMesh instancing for the enemy and particle shaders, the arena passes, additive layers for beams and the
## Cinder glow) for FRAMES frames at a near-zero alpha, then frees itself. It must really be on screen: a fully
## transparent or off-screen draw is culled and compiles nothing. Meshes, textures and shader sources come from the
## game's own factories and constants (`EnemyRenderer`, `ParticleRenderer`, `ArenaBackground`, `CinderLayer`,
## `ArtSlots`); no shader code is copied. The first frames sit under the Main background and render at 1/20 size.

const FRAMES: int = 2
const ALPHA: float = 0.02
const SPOT: Vector2 = Vector2(6.0, 6.0)
const SCALE: float = 0.12

var _frames: int = 0


## Adds a warm-up node to `parent` (call once from the main scene's `_ready`).
static func start(parent: Node) -> ShaderWarmup:
	var w := ShaderWarmup.new()
	parent.add_child(w)
	return w


## Frames this node has been processed (tests).
func frames() -> int:
	return _frames


func _ready() -> void:
	position = SPOT
	scale = Vector2(SCALE, SCALE)
	modulate = Color(1.0, 1.0, 1.0, ALPHA)
	z_index = 100
	_add_enemy()
	_add_particles()
	_add_arena()
	_add_additive_layer()
	_add_title()


@warning_ignore("unused_parameter")
func _process(delta: float) -> void:  # gdlint: ignore=unused-argument
	_frames += 1
	if _frames > FRAMES:
		queue_free()


func _add_enemy() -> void:
	var slot_id: String = EnemyRenderer.ENEMY_SLOTS[0]
	var art: ArtSlot = ArtSlots.slot(slot_id)
	var glow_art: ArtSlot = ArtSlots.glow_of(slot_id)
	var mat := ShaderMaterial.new()
	mat.shader = load(EnemyRenderer.SHADER_PATH) as Shader
	mat.set_shader_parameter("glow_tex", ArtSlots.texture(glow_art.id) if glow_art.valid else ArtSlots.placeholder())
	var data := PackedFloat32Array([0.0, 0.0, 1.0, 0.0])  # one texel: flash, frame, spawn-in, phase
	mat.set_shader_parameter("u_inst", ImageTexture.create_from_image(MultiMeshBuffer.data_image(data)))
	_add_instance(mat, ArtSlots.texture(slot_id), EnemyRenderer.quad_mesh(art, art.sprite_scale()))


func _add_particles() -> void:
	var base: Shader = load(ParticleRenderer.SHADER_PATH) as Shader
	var pool := ParticlePool.new()
	pool.setup(1)
	var data_tex: ImageTexture = ImageTexture.create_from_image(ParticleRenderer.data_image(pool))
	var tex: Texture2D = ArtSlots.texture(ParticlePack.SLOTS[ParticlePack.KIND_FLASH])
	for shader: Shader in [base, ParticleRenderer.make_mix_shader()]:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("u_data", data_tex)
		_add_instance(mat, tex, _quad(64.0))


func _add_arena() -> void:
	var fx := ShaderMaterial.new()
	fx.shader = ArenaBackground.FX_SHADER
	fx.set_shader_parameter("floor_tex", ArtSlots.texture(ArenaBackground.FLOOR_SLOT))
	var overlay := ShaderMaterial.new()
	overlay.shader = ArenaBackground.OVERLAY_SHADER
	for mat: ShaderMaterial in [fx, overlay]:
		var r := ColorRect.new()
		r.material = mat
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.size = Vector2(64.0, 64.0)
		add_child(r)


## Beam and Cinder glow draw additively through a `CinderLayer` (same CanvasItemMaterial as the beam renderer).
func _add_additive_layer() -> void:
	var layer := CinderLayer.new()
	layer.make_additive()
	var tex: Texture2D = ArtSlots.texture(ParticlePack.SLOTS[ParticlePack.KIND_FLASH])
	layer.painter = func(c: CanvasItem) -> void:
		c.draw_texture_rect(tex, Rect2(0.0, 0.0, 64.0, 64.0), false)
		c.draw_polyline_colors(
			PackedVector2Array([Vector2(0.0, 0.0), Vector2(64.0, 64.0)]),
			PackedColorArray([Color.WHITE, Color.WHITE]),
			3.0
		)
	add_child(layer)


## The title materials (M3-30): the fbm smoke band (its additive variant is a uniform) and the shimmering logo.
## Embers reuse the particle shaders above.
func _add_title() -> void:
	var smoke: ColorRect = TitleArt.smoke_rect(0, TitleArt.far_haze())
	smoke.size = Vector2(64.0, 64.0)
	add_child(smoke)
	var logo := TitleLogo.new()
	logo.setup()
	logo.scale = Vector2(0.05, 0.05)
	add_child(logo)


## One-instance, transform-only MultiMesh (instanced draw path), as in the game: the enemy and particle shaders read
## their per-instance fields from a data texture, never from instance COLOR / CUSTOM (V1-26, V1-29).
func _add_instance(mat: ShaderMaterial, tex: Texture2D, mesh: Mesh) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = false
	mm.use_custom_data = false
	mm.mesh = mesh
	mm.instance_count = 1
	mm.set_instance_transform_2d(0, Transform2D.IDENTITY)
	var inst := MultiMeshInstance2D.new()
	inst.multimesh = mm
	inst.texture = tex
	inst.material = mat
	inst.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(inst)


static func _quad(size_px: float) -> ArrayMesh:
	var h: float = size_px * 0.5
	var arrays: Array = []
	if arrays.resize(Mesh.ARRAY_MAX) != OK:
		push_error("ShaderWarmup: quad arrays resize failed")
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
