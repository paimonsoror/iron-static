class_name CinderLayer
extends Node2D
## One canvas layer of the Cinder rig: calls `painter(self)` from `_draw`. The body layer paints with normal blend,
## the glow layer carries an additive `CanvasItemMaterial` (V1-11). Each layer is one texture, so one draw call.

var painter: Callable = Callable()


func _draw() -> void:
	if painter.is_valid():
		painter.call(self)


## Switches the layer to additive blending (glow sheet compositing, art bible 10).
func make_additive() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
