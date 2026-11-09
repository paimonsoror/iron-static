class_name TitleParallax
extends RefCounted
## The five parallax layers of the title (back to front: sky, far spires, mid hulks, near ridge, front ridge) and
## the hero: the selected frame's silhouette on the near ridge with its additive core glow. `TitleFx` adds the
## sprites to the stage in draw order between its smoke layers. Drift off (and the glow held) under reduce motion.

var layers: Array[Sprite2D] = []
var frame_id_shown: String = ""

var _base_pos: PackedVector2Array = PackedVector2Array()
var _sil: Sprite2D = null
var _glow: Sprite2D = null


func build() -> void:
	for i: int in TitleArt.LAYER_NAMES.size():
		var layer: Sprite2D = TitleArt.sprite(TitleArt.LAYER_NAMES[i], TitleArt.LAYER_SCALE[i])
		layer.position = Vector2(0.0, TitleArt.LAYER_Y[i])
		layers.append(layer)
		_base_pos.append(layer.position)
	var ridge: Sprite2D = layers[3]
	var ls: float = TitleArt.LAYER_SCALE[3]
	var perch: Vector2 = TitleArt.PERCH / ls
	_sil = TitleArt.sprite_pivot("", TitleArt.SIL_PIVOT, TitleArt.SIL_SCALE / ls)
	_sil.position = perch
	ridge.add_child(_sil)
	_glow = TitleArt.sprite_pivot("", TitleArt.GLOW_PIVOT, _glow_scale())
	_glow.position = perch
	_glow.material = TitleArt.additive()
	ridge.add_child(_glow)


func _glow_scale() -> float:
	return TitleArt.GLOW_SCALE / TitleArt.LAYER_SCALE[3]


## Shows the silhouette and glow of `frame_id` ("vanguard", "bulwark", "striker"); only those sheets are loaded.
func set_frame(frame_id: String) -> void:
	if not TitleArt.FRAMES.has(frame_id):
		push_error("title: unknown frame " + frame_id)
		return
	if frame_id == frame_id_shown:
		return
	frame_id_shown = frame_id
	_sil.texture = TitleArt.tex("sil_" + frame_id)
	_glow.texture = TitleArt.tex("sil_" + frame_id + "_glow")


## Stretches the sky upward by `extra` px (a view taller than the 2400 reference).
func stretch_sky(extra: float) -> void:
	var sky: Sprite2D = layers[0]
	_base_pos[0] = Vector2(0.0, -extra)
	var sky_s: float = TitleArt.LAYER_SCALE[0]
	sky.scale = Vector2(sky_s, sky_s + extra / float(sky.texture.get_height()))


## Drift and core pulse at view time `t` (seconds); `reduce_motion` freezes both.
func tick(t: float, reduce_motion: bool) -> void:
	var tm: float = 0.0 if reduce_motion else t
	for i: int in layers.size():
		var amp: float = TitleArt.LAYER_AMP[i]
		var ph: float = TAU * tm / TitleArt.LAYER_PERIOD[i]
		layers[i].position = _base_pos[i] + Vector2(amp * sin(ph), amp * 0.12 * sin(ph * 1.7 + 1.0))
	var pulse: float = 0.5 if reduce_motion else 0.5 + 0.5 * sin(TAU * t / 2.6)
	_glow.modulate = Color(1.0, 1.0, 1.0, 0.72 + 0.28 * pulse)
	_glow.scale = Vector2.ONE * _glow_scale() * (1.0 + 0.04 * pulse)


## Faint ground-light change while a flare is on (`env` 0-1).
func apply_flare(env: float) -> void:
	layers[0].modulate = Color(1.0 + 0.45 * env, 1.0 + 0.35 * env, 1.0 + 0.2 * env, 1.0)
	layers[3].modulate = Color(1.0 + 0.25 * env, 1.0 + 0.2 * env, 1.0 + 0.1 * env, 1.0)
