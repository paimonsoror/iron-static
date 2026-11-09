class_name TitleArt
extends RefCounted
## Layout table, loaders and shader parameters of the production title screen (M3-28, view code, no sim access).
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
## Draw scale per layer: the sheets are rasterized smaller than the stage to save texture memory.
const LAYER_SCALE: PackedFloat32Array = [3.0, 2.6666667, 1.3333334, 1.3333334, 2.0]
const LAYER_AMP: PackedFloat32Array = [0.0, 6.0, 14.0, 24.0, 38.0]
const LAYER_PERIOD: PackedFloat32Array = [60.0, 53.0, 41.0, 33.0, 27.0]
## Cinder's feet on the ridge_near layer in stage px, the silhouette and glow draw scale (stage px per texel), and
## their pivots in texels (sil sheets are 420 x 588 shown 1:1; glow sheets 210 x 294 shown 2x).
const PERCH: Vector2 = Vector2(1040.0, 210.0)
const SIL_SCALE: float = 1.0
const GLOW_SCALE: float = 2.0
const SIL_PIVOT: Vector2 = Vector2(210.0, 564.2)
const GLOW_PIVOT: Vector2 = Vector2(105.0, 282.1)
const FRAMES: Array[String] = ["vanguard", "bulwark", "striker"]
## Smoke layers: top y and height. Layer 0 is the sky haze (horizon haze plus the high band in the top third).
const SMOKE_Y: PackedFloat32Array = [0.0, 1360.0, 1700.0]
const SMOKE_H: PackedFloat32Array = [1660.0, 780.0, 700.0]
const LOGO_SCALE: float = 1.1
const LOGO_SHEET_W: float = 960.0

static var _tex: Dictionary = {}


## Drops the cached textures (tests; the engine frees them when nothing else holds a reference).
static func clear_cache() -> void:
	_tex.clear()


static func tex(sheet: String) -> Texture2D:
	if not _tex.has(sheet):
		var path: String = DIR + sheet + ".svg"
		var loaded: Texture2D = load(path) as Texture2D
		if loaded == null:
			push_error("title: missing texture " + path)
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
	if sheet != "":
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


static func smoke_rect(idx: int, params: Dictionary) -> ColorRect:
	var size := Vector2(STAGE_W, SMOKE_H[idx])
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


static func far_haze() -> Dictionary:
	# horizon haze (uv.y above hi_end) and the high drifting band that frames the logo (uv.y below hi_end)
	return {
		"density": 0.95,
		"noise_scale": 3.1,
		"drift": Vector2(0.016, -0.005),
		"additive": 0.12,
		"edge_lo": 0.4,
		"edge_hi": 0.66,
		"col_dark": Color(0.1, 0.06, 0.045),
		"col_warm": Color(1.0, 0.45, 0.1),
		"warm_y": 0.92,
		"warm_amount": 0.8,
		"fade_top": 0.2,
		"fade_bottom": 0.136,
		"hi_end": 0.54,
		"hi_density": 0.78,
		"hi_scale": 2.6,
		"hi_drift": Vector2(0.011, -0.002),
		"hi_edge_lo": 0.36,
		"hi_edge_hi": 0.7,
		"hi_dark": Color(0.045, 0.035, 0.035),
		"hi_warm": Color(0.95, 0.5, 0.18),
		"hi_warm_y": 0.5,
		"hi_hole_y": 0.32,
		"hi_hole_h": 0.1,
		"hi_hole_amount": 0.6,
	}


static func mid_smoke() -> Dictionary:
	return {
		"density": 1.0,
		"noise_scale": 2.6,
		"drift": Vector2(0.021, -0.006),
		"additive": 0.0,
		"edge_lo": 0.42,
		"edge_hi": 0.66,
		"col_dark": Color(0.025, 0.02, 0.022),
		"col_warm": Color(0.85, 0.36, 0.1),
		"warm_y": 0.3,
		"warm_amount": 0.4,
		"fade_top": 0.35,
		"fade_bottom": 0.3,
	}


static func low_fog() -> Dictionary:
	return {
		"density": 0.8,
		"noise_scale": 2.8,
		"drift": Vector2(0.034, -0.002),
		"additive": 0.0,
		"edge_lo": 0.38,
		"edge_hi": 0.7,
		"col_dark": Color(0.02, 0.02, 0.025),
		"col_warm": Color(0.6, 0.25, 0.08),
		"warm_y": 0.1,
		"warm_amount": 0.2,
		"fade_top": 0.45,
		"fade_bottom": 0.12,
	}
