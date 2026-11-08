class_name StyleFrameCinder
extends Node2D
## Static Cinder rig for the style frame, assembled exactly like the reference mock
## (build/svg/cinder/assembled_onscreen_b0_b3.svg): body layers at 0.5 px per texel, glow layers at 1.0.
## Origin = body center. Band 0..3 picks wedge states (CinderWedges), core, crack and glow cells.

const RING_AIM_DEG: float = -35.0
const SHADOW_OFFSET: Vector2 = Vector2(8.0, 12.0)
const SHADOW_SCALE: float = 0.575
const SHOULDER_POS: Vector2 = Vector2(-125.0, -22.0)
const EMITTER_RADIUS_PX: float = 100.0
var glow_on: bool = true:
	set(value):
		glow_on = value
		for g: Sprite2D in _glows:
			g.visible = value

var _glows: Array[Sprite2D] = []
var _halo: Sprite2D = null
var _t: float = 0.0


## World-space (relative to origin) position of emitter node `k` (0..2).
static func emitter_pos(k: int) -> Vector2:
	var a: float = deg_to_rad(-90.0 + RING_AIM_DEG + 120.0 * float(k))
	return Vector2.from_angle(a) * EMITTER_RADIUS_PX


func build(band: int) -> void:
	for c: Node in get_children():
		c.queue_free()
	_glows.clear()
	_halo = null
	var body: Texture2D = StyleFrameArt.tex("cinder")
	var glow: Texture2D = StyleFrameArt.tex("cinder_glow")
	var s: float = StyleFrameArt.BODY_SCALE
	var sh: Sprite2D = StyleFrameArt.sprite_c(self, body, Rect2(672, 576, 336, 336), SHADOW_SCALE, false)
	sh.position = SHADOW_OFFSET
	StyleFrameArt.sprite_c(self, body, Rect2(0, 0, 448, 448), s, false)
	_g(StyleFrameArt.sprite(self, glow, Rect2(0, 0, 216, 216), Vector2(108, 108), 1.0, true), 0.9)
	_build_wedges(band, body, glow)
	StyleFrameArt.sprite_c(self, body, Rect2(512, 448, 160, 160), s, false)
	_build_core(band, body, glow)
	var ring := Node2D.new()
	ring.rotation = deg_to_rad(RING_AIM_DEG)
	add_child(ring)
	StyleFrameArt.sprite_c(ring, body, Rect2(448, 0, 448, 448), s, false)
	_g(StyleFrameArt.sprite(ring, glow, Rect2(216, 0, 224, 224), Vector2(112, 112), 1.0, true), 1.0)
	var visor := Node2D.new()
	visor.rotation = deg_to_rad(RING_AIM_DEG)
	add_child(visor)
	StyleFrameArt.sprite(visor, body, Rect2(0, 576, 160, 48), Vector2(80, 164), s, false)
	_g(StyleFrameArt.sprite(visor, glow, Rect2(248, 432, 100, 44), Vector2(53, 90), 1.0, true), 1.0)
	var sho := Node2D.new()
	sho.position = SHOULDER_POS
	add_child(sho)
	StyleFrameArt.sprite(sho, body, Rect2(448, 608, 224, 160), Vector2(150, 96), s, false)
	var lens: Sprite2D = StyleFrameArt.sprite_c(sho, glow, Rect2(440, 312, 72, 72), 1.0, true)
	lens.position = Vector2(-33.0, -11.0)
	_g(lens, 1.0)
	_build_ticks(body, glow)


func _g(sp: Sprite2D, alpha: float) -> void:
	sp.modulate.a = alpha
	sp.visible = glow_on
	_glows.append(sp)


func _build_wedges(band: int, body: Texture2D, glow: Texture2D) -> void:
	var states: PackedInt32Array = CinderWedges.states(band)
	for k: int in CinderWedges.WEDGE_COUNT:
		var st: int = states[k]
		if st == CinderWedges.GONE:
			continue
		var even: bool = k % 2 == 0
		var cell_x: int = 0 if even else 128
		if st == CinderWedges.CHARRED:
			cell_x += 256
		var w: Sprite2D = StyleFrameArt.sprite(
			self, body, Rect2(cell_x, 448, 128, 112), Vector2(64, 196), StyleFrameArt.BODY_SCALE, false
		)
		w.rotation = deg_to_rad(30.0 * float(k))
		var gr: Rect2 = Rect2(440, 144, 72, 64)
		if st == CinderWedges.CHARRED:
			gr = Rect2(440, 0 if even else 72, 72, 64)
		var gs: Sprite2D = StyleFrameArt.sprite(self, glow, gr, Vector2(36, 102), 1.0, true)
		gs.rotation = w.rotation
		_g(gs, 1.0)


func _build_core(band: int, body: Texture2D, glow: Texture2D) -> void:
	var hot: bool = band >= 3
	if hot:
		StyleFrameArt.sprite_c(self, body, Rect2(0, 768, 128, 128), StyleFrameArt.BODY_SCALE, false)
		_halo = StyleFrameArt.sprite_c(self, glow, Rect2(248, 232, 192, 192), 1.0, true)
	else:
		StyleFrameArt.sprite_c(self, body, Rect2(672, 448, 128, 128), StyleFrameArt.BODY_SCALE, false)
		_halo = StyleFrameArt.sprite_c(self, glow, Rect2(0, 232, 248, 248), 1.0, true)
	_g(_halo, 0.7)
	if band >= 2:
		StyleFrameArt.sprite_c(self, body, Rect2(800, 448, 128, 128), StyleFrameArt.BODY_SCALE, false)
		_g(StyleFrameArt.sprite_c(self, glow, Rect2(440, 232, 72, 72), 1.0, true), 1.0)


## Integrity tick strip under the body (no mock reference: placed as a small gauge, noted in the report).
func _build_ticks(body: Texture2D, glow: Texture2D) -> void:
	var t: Sprite2D = StyleFrameArt.sprite(
		self, body, Rect2(0, 704, 448, 64), Vector2(224, 32), StyleFrameArt.BODY_SCALE * 0.9, false
	)
	t.position = Vector2(0.0, 122.0)
	var h: Sprite2D = StyleFrameArt.sprite(self, glow, Rect2(248, 480, 224, 28), Vector2(112, 14), 0.9, true)
	h.position = t.position
	_g(h, 0.8)


func _process(delta: float) -> void:
	_t += delta
	if _halo != null:
		_halo.modulate.a = 0.7 + 0.08 * sin(_t * TAU)
