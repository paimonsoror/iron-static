class_name UtPlates
extends Node2D
## Style-frame armor plates: cells of the mockup sheet `ut_plates.svg` (and its additive glow twin) drawn centered on
## Cinder, under the production rig layers. Debug only. Production: three extra cells in the `cinder` / `cinder_glow`
## sheets drawn by CinderRig between the shadow and the frame (spec 12 s7), so they batch with the body layer.
## `count` = plate tiers drawn (0..3): tier 1 = cell 0, tier 2 adds cell 1, tier 3 adds cell 2.

const CELL: float = 640.0
const BODY_PATH: String = "res://assets/art/style/upgrade_tiers/ut_plates.svg"
const GLOW_PATH: String = "res://assets/art/style/upgrade_tiers/ut_plates_glow.svg"

var count: int = 0
## Texel to px on screen: 0.5 px per texel times the rig scale (CinderLayout.rig_scale).
var px_per_texel: float = 0.32
var glow_alpha: float = 1.0
var _tex: Texture2D = null
var _glow: Texture2D = null


func _ready() -> void:
	_tex = load(BODY_PATH) as Texture2D
	_glow = load(GLOW_PATH) as Texture2D


func _draw() -> void:
	if _tex == null:
		return
	var s: float = CELL * px_per_texel
	for k: int in count:
		draw_texture_rect_region(_tex, Rect2(-s * 0.5, -s * 0.5, s, s), Rect2(float(k) * CELL, 0.0, CELL, CELL))


## Additive twin: put this on a node with an additive CanvasItemMaterial.
class Glow:
	extends Node2D
	var plates: UtPlates = null

	func _draw() -> void:
		if plates == null or plates._glow == null:
			return
		var s: float = UtPlates.CELL * plates.px_per_texel
		for k: int in plates.count:
			var r := Rect2(-s * 0.5, -s * 0.5, s, s)
			var c := Color(1.0, 1.0, 1.0, plates.glow_alpha)
			draw_texture_rect_region(
				plates._glow, r, Rect2(float(k) * UtPlates.CELL, 0.0, UtPlates.CELL, UtPlates.CELL), c
			)
