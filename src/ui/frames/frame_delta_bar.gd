class_name FrameDeltaBar
extends Control
## Centered comparison bar of the frame bay (M3-29): the middle mark is the reference frame, a fill to the right is
## better (amber), to the left is worse (dim gray, never red). `pct` is the percent change; full at +/-100.

const HEIGHT: float = 30.0
const INSET: float = 3.0

var pct: float = 0.0:
	set(v):
		pct = v
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(120.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Palette.GRID)
	draw_rect(r, Palette.UNAFFORDABLE, false, 2.0)
	var mid: float = size.x * 0.5
	var half: float = mid - INSET
	var f: float = FrameBayModel.bar_fraction(pct)
	var s: int = FrameBayModel.sign_of(pct)
	if s != 0:
		var w: float = maxf(absf(f) * half, 4.0)
		var x: float = mid if s > 0 else mid - w
		var c: Color = Palette.AMBER if s > 0 else Palette.TEXT_DIM
		draw_rect(Rect2(x, INSET, w, size.y - 2.0 * INSET), c)
	draw_line(Vector2(mid, 0.0), Vector2(mid, size.y), Palette.TEXT, 2.0)
