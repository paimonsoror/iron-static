class_name StyleFrameArt
extends RefCounted
## Shared loaders and sprite helpers for the V1-01 style frame (debug only, view code, no sim access).
## Texel density D = 2 for Cinder, enemies and bolt (0.5 px per texel); glow sheets are half size, so a glow
## sprite uses scale 1.0 for the same pixel size (art bible 4.3).

const DIR: String = "res://assets/art/src/"
const SHADER_ENEMY: String = "res://assets/shaders/style_frame_enemy.gdshader"
const SHADER_ARENA: String = "res://assets/shaders/style_frame_arena.gdshader"
const BODY_SCALE: float = 0.5
## OpenType variation tag "wght" (0x77676874).
const WGHT_TAG: int = 0x77676874

static var _tex: Dictionary = {}
static var _add_mat: CanvasItemMaterial = null


static func tex(slot: String) -> Texture2D:
	if not _tex.has(slot):
		var path: String = DIR + slot + ".svg"
		var loaded: Texture2D = load(path) as Texture2D
		if loaded == null:
			push_error("style frame: missing texture " + path)
		_tex[slot] = loaded
	var v: Variant = _tex[slot]
	var t: Texture2D = v
	return t


## Shared additive material for glow and light sprites.
static func additive() -> CanvasItemMaterial:
	if _add_mat == null:
		_add_mat = CanvasItemMaterial.new()
		_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add_mat


## Sprite showing `region` of a sheet. `pivot` (texels, relative to the region) lands on the node origin.
static func sprite(
	parent: Node2D, texture: Texture2D, region: Rect2, pivot: Vector2, scale_f: float, glow: bool
) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture
	s.region_enabled = true
	s.region_rect = region
	s.region_filter_clip_enabled = true
	s.centered = false
	s.offset = -pivot
	s.scale = Vector2(scale_f, scale_f)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if glow:
		s.material = additive()
	parent.add_child(s)
	return s


## Same as sprite() with the pivot at the region center.
static func sprite_c(parent: Node2D, texture: Texture2D, region: Rect2, scale_f: float, glow: bool) -> Sprite2D:
	return sprite(parent, texture, region, region.size * 0.5, scale_f, glow)


## Unit-UV quad of `size` px whose texel `pivot_frac` (0..1 of the quad) sits at the origin.
static func quad_mesh(size: Vector2, pivot_px: Vector2) -> ArrayMesh:
	var x0: float = -pivot_px.x
	var y0: float = -pivot_px.y
	var x1: float = x0 + size.x
	var y1: float = y0 + size.y
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Enemy shader material (body + glow composite). `frames` = body frames along x for whole-sheet quads.
static func enemy_material(glow_slot: String, body_frames: int, glow_frames: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_ENEMY) as Shader
	m.set_shader_parameter("glow_tex", tex(glow_slot))
	m.set_shader_parameter("body_frames", body_frames)
	m.set_shader_parameter("glow_frames", glow_frames)
	return m


static func font_body() -> Font:
	return _variation(450)


static func font_number() -> Font:
	return load("res://assets/fonts/ShareTechMono-Regular.ttf") as Font


static func font_heading() -> Font:
	return _variation(600)


static func _variation(weight: int) -> Font:
	var fv := FontVariation.new()
	fv.base_font = load("res://assets/fonts/Oxanium-Variable.ttf") as Font
	fv.variation_opentype = {WGHT_TAG: weight}
	return fv
