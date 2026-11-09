class_name TierUpFlash
extends Node2D
## Cinder's tier-up flash (VT-5, docs/design/12 s5 and s8; mock `UtFlash`): a soft halo, an expanding teal-white ring,
## an amber thin ring and an 8-point flare, four additive quads from the `fx_sheet` cells, 0.45 s. Quality rules:
## MID halo and one ring; LOW one halo, 0.2 s; reduce motion a steady 0.25 s glow without an expanding ring. The
## node sits on Cinder (the battle view's origin) and redraws only while a flash runs.

enum Mode { FULL, MID, LOW, STEADY }

const DURATIONS: Array[float] = [0.45, 0.45, 0.2, 0.25]

var radius_px: float = 110.0
var _mode: Mode = Mode.FULL
var _start_s: float = -1.0
var _t: float = -1.0


func _init() -> void:
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


static func duration_s(mode: Mode) -> float:
	return DURATIONS[mode]


## The flash mode for a quality tier and the reduce-motion switch.
static func mode_for(tier: int, reduce_motion: bool) -> Mode:
	if reduce_motion:
		return Mode.STEADY
	if tier == VisualQuality.Tier.LOW:
		return Mode.LOW
	return Mode.MID if tier == VisualQuality.Tier.MID else Mode.FULL


## Number of quads a mode draws.
static func quad_count(mode: Mode) -> int:
	match mode:
		Mode.FULL:
			return 4
		Mode.MID:
			return 2
	return 1


func start(now_s: float, mode: Mode) -> void:
	_mode = mode
	_start_s = now_s
	_t = 0.0
	visible = true
	queue_redraw()


## Advances the clock; hides the node when the flash is over.
func update(now_s: float) -> void:
	if _start_s < 0.0:
		return
	_t = now_s - _start_s
	if _t >= duration_s(_mode):
		_start_s = -1.0
		_t = -1.0
		visible = false
	queue_redraw()


func is_running() -> bool:
	return _start_s >= 0.0


func _draw() -> void:
	if _t < 0.0:
		return
	var u: float = clampf(_t / duration_s(_mode), 0.0, 1.0)
	var fade: float = 1.0 - u
	var sheet: Texture2D = ArtSlots.texture("fx_halo_soft")
	var halo: Rect2 = ArtSlots.slot("fx_halo_soft").frame_rect(0)
	var steady: bool = _mode == Mode.STEADY
	var hs: float = radius_px * (3.8 if steady else lerpf(3.4, 5.2, u))
	var hc: Color = Palette.AMBER_GLOW
	hc.a = 0.5 * fade
	_quad(sheet, halo, hs, hc)
	if _mode == Mode.LOW or steady:
		return
	var ring: Rect2 = ArtSlots.slot("fx_ring_thick").frame_rect(0)
	var rc: Color = Palette.TEAL.lerp(Color.WHITE, 0.45)
	rc.a = 0.9 * fade
	_quad(sheet, ring, radius_px * lerpf(2.4, 6.0, 1.0 - pow(1.0 - u, 2.0)), rc)
	if _mode == Mode.MID:
		return
	var ring2: Rect2 = ArtSlots.slot("fx_ring_thin").frame_rect(0)
	var r2c: Color = Palette.AMBER_GLOW
	r2c.a = 0.8 * fade
	_quad(sheet, ring2, radius_px * lerpf(2.0, 4.2, 1.0 - pow(1.0 - u, 3.0)), r2c)
	var star: Rect2 = ArtSlots.slot("fx_flare_star_8").frame_rect(0)
	_quad(sheet, star, radius_px * lerpf(2.2, 3.6, u), Color(1.0, 0.96, 0.85, 0.75 * fade))


func _quad(sheet: Texture2D, src: Rect2, size: float, color: Color) -> void:
	draw_texture_rect_region(sheet, Rect2(-size * 0.5, -size * 0.5, size, size), src, color)
