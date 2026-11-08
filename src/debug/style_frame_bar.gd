class_name StyleFrameBar
extends Control
## Segmented bar drawn inside a ui_kit bar_frame (segments inset 6 px, art bible 7.1/7.2) with optional tick row.

const SEG_ON: Rect2 = Rect2(312, 208, 24, 24)
const SEG_OFF: Rect2 = Rect2(344, 208, 24, 24)
const TICK_MINOR: Rect2 = Rect2(376, 208, 8, 16)
const TICK_MAJOR: Rect2 = Rect2(392, 208, 8, 24)
const INSET: float = 6.0

var segments: int = 20
var lit: int = 10
var colors: PackedColorArray = PackedColorArray([Palette.AMBER])
var ticks: bool = false
var head_bright: bool = false
var _kit: Texture2D = null


func _ready() -> void:
	_kit = StyleFrameArt.tex("ui_kit")


func _draw() -> void:
	var inner: Rect2 = Rect2(INSET, INSET, size.x - 2.0 * INSET, size.y - 2.0 * INSET)
	var pitch: float = inner.size.x / float(segments)
	for i: int in segments:
		var r := Rect2(inner.position.x + pitch * float(i) + 1.0, inner.position.y, pitch - 2.0, inner.size.y)
		if i < lit:
			var c: Color = colors[mini(floori(float(i * colors.size()) / float(segments)), colors.size() - 1)]
			if head_bright and i == lit - 1:
				c = c.lightened(0.55)
			draw_texture_rect_region(_kit, r, SEG_ON, c)
		else:
			draw_texture_rect_region(_kit, r, SEG_OFF, Color.WHITE)
	if ticks:
		for k: int in 11:
			var x: float = inner.position.x + inner.size.x * float(k) / 10.0
			draw_texture_rect_region(_kit, Rect2(x - 1.0, size.y + 2.0, 2.0, 8.0), TICK_MINOR, Palette.AMBER_DIM)
		for q: int in 3:
			var xq: float = inner.position.x + inner.size.x * float(q + 1) * 0.25
			draw_texture_rect_region(_kit, Rect2(xq - 1.5, size.y + 2.0, 3.0, 16.0), TICK_MAJOR, Palette.AMBER_DIM)
