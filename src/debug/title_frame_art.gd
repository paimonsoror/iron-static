class_name TitleFrameArt
extends RefCounted
## Layout table and loaders of the M3-25 title style frame (debug only, view code, no sim access).
## Stage coordinates: the art stage is 2160 wide (2 x 1080, the wide layout crops it) and 2400 tall (the portrait
## reference); it is anchored to the bottom of the viewport, so a shorter viewport simply loses sky.

const DIR: String = "res://assets/art/title/src/"
const SHADER_SMOKE: String = "res://assets/shaders/title_smoke.gdshader"
const SHADER_LOGO: String = "res://assets/shaders/title_logo.gdshader"
const SHADER_OVERLAY: String = "res://assets/shaders/arena_overlay.gdshader"
const STAGE_W: float = 2160.0
const REF_H: float = 2400.0
## Parallax layers back to front: sheet name, top y on the stage, draw scale, drift amplitude px, drift period s.
const LAYER_NAMES: Array[String] = ["sky_glow", "spires_far", "hulks_mid", "ridge_near", "ridge_front"]
const LAYER_Y: PackedFloat32Array = [0.0, 880.0, 1030.0, 1440.0, 1960.0]
const LAYER_SCALE: PackedFloat32Array = [2.0, 2.0, 1.0, 1.0, 1.0]
const LAYER_AMP: PackedFloat32Array = [0.0, 6.0, 14.0, 24.0, 38.0]
const LAYER_PERIOD: PackedFloat32Array = [60.0, 53.0, 41.0, 33.0, 27.0]
## Cinder's feet on the ridge_near layer (layer-local texels) and the silhouette draw scale.
const PERCH: Vector2 = Vector2(1040.0, 210.0)
const SIL_SCALE: float = 0.7
const SIL_PIVOT: Vector2 = Vector2(300.0, 806.0)
const GLOW_PIVOT: Vector2 = Vector2(150.0, 403.0)
## Smoke layers: top y, height, then the shader parameters (see title_smoke.gdshader).
const SMOKE_Y: PackedFloat32Array = [760.0, 1360.0, 1700.0]
const SMOKE_H: PackedFloat32Array = [900.0, 780.0, 700.0]

static var _tex: Dictionary = {}


static func tex(sheet: String) -> Texture2D:
	if not _tex.has(sheet):
		var path: String = DIR + sheet + ".svg"
		var loaded: Texture2D = load(path) as Texture2D
		if loaded == null:
			push_error("title frame: missing texture " + path)
		_tex[sheet] = loaded
	var v: Variant = _tex[sheet]
	var t: Texture2D = v
	return t


static func additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## Sprite with its top-left at the node origin, scaled uniformly.
static func sprite(sheet: String, scale_f: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex(sheet)
	s.centered = false
	s.scale = Vector2(scale_f, scale_f)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return s


## Sprite whose `pivot` (texels) sits on the node origin.
static func sprite_pivot(sheet: String, pivot: Vector2, scale_f: float) -> Sprite2D:
	var s: Sprite2D = sprite(sheet, scale_f)
	s.offset = -pivot
	return s


static func smoke_rect(idx: int, size: Vector2, params: Dictionary) -> ColorRect:
	var r := ColorRect.new()
	r.position = Vector2(0.0, SMOKE_Y[idx])
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = load(SHADER_SMOKE) as Shader
	m.set_shader_parameter("rect_px", size)
	for k: Variant in params:
		m.set_shader_parameter(str(k), params[k])
	r.material = m
	return r


static func font_heading() -> Font:
	return ThemeBuilder.shared().get_font(&"font", &"LabelHeading")
