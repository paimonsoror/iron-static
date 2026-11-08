class_name StyleFrameFx
extends Node2D
## Procedural beams (glow + core + hot center), muzzle flashes and impact sparks for the style frame.
## Origin = Cinder (world space). Additive material; fx cells come from fx_sheet.svg (128 px cells, tint in code).

const CELL: float = 128.0
const COL_HALO: int = 0
const COL_FLASH_DISC: int = 1
const COL_STAR4: int = 2
const COL_STAR8: int = 3
const COL_RING_THIN: int = 4

var starts: PackedVector2Array = PackedVector2Array()
var ends: PackedVector2Array = PackedVector2Array()
var _t: float = 0.0
var _tex: Texture2D = null


func _ready() -> void:
	material = StyleFrameArt.additive()
	_tex = StyleFrameArt.tex("fx_sheet")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func set_beams(s: PackedVector2Array, e: PackedVector2Array) -> void:
	starts = s
	ends = e
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _fx(col: int, row: int, center: Vector2, size_px: float, tint: Color, rot: float = 0.0) -> void:
	draw_set_transform(center, rot, Vector2.ONE)
	var half: float = size_px * 0.5
	draw_texture_rect_region(
		_tex, Rect2(-half, -half, size_px, size_px), Rect2(float(col) * CELL, float(row) * CELL, CELL, CELL), tint
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _line(a: Vector2, b: Vector2, w: float, c: Color) -> void:
	draw_line(a, b, c, w, true)


func _draw() -> void:
	for i: int in starts.size():
		_draw_beam(i)


func _draw_beam(i: int) -> void:
	var a: Vector2 = starts[i]
	var b: Vector2 = ends[i]
	var dir: Vector2 = (b - a).normalized()
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var jit: float = 1.0 + 0.12 * sin(_t * 31.0 + float(i) * 2.0)
	var wob: Vector2 = side * 2.0 * sin(_t * 47.0 + float(i))
	var a2: Vector2 = a + wob
	var b2: Vector2 = b + wob
	# soft glow: stacked lines up to 36 px wide, 55% total amber
	var glow: Color = Palette.LASER_GLOW
	for k: int in 4:
		var w: float = lerpf(36.0, 14.0, float(k) / 3.0) * jit
		_line(a2, b2, w, Color(glow.r, glow.g, glow.b, 0.14))
	_line(a2, b2, 8.0 * jit, Palette.LASER_CORE)
	_line(a2, b2, 3.0, Color.WHITE)
	# muzzle flash at the emitter
	var mp: float = 0.8 + 0.2 * sin(_t * 40.0 + float(i))
	_fx(COL_STAR4, 0, a, 64.0 * mp, Palette.CORE, 0.2)
	_fx(COL_HALO, 0, a, 54.0, Palette.CORE)
	# impact: flash disc, thin ring, radial sparks
	_fx(COL_FLASH_DISC, 0, b, 28.0, Color.WHITE)
	_fx(COL_HALO, 0, b, 62.0, Color(glow.r, glow.g, glow.b, 0.7))
	_fx(COL_RING_THIN, 0, b, 40.0 + 30.0 * fmod(_t * 6.0 + float(i) * 0.3, 1.0), Color(1, 1, 1, 0.6))
	for s: int in 6:
		var ang: float = TAU * float(s) / 6.0 + float(i) * 0.5 + 0.2 * sin(_t * 9.0 + float(s))
		var len_px: float = 18.0 + 16.0 * fmod(float(s) * 0.37 + _t * 3.0, 1.0)
		var d: float = 10.0 + 12.0 * fmod(float(s) * 0.61 + _t * 2.0, 1.0)
		_fx(s % 3, 1, b + Vector2.from_angle(ang) * d, len_px * 2.0, Palette.LASER_CORE, ang)
