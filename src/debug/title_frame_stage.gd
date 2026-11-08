class_name TitleFrameStage
extends Node2D
## The art stage of the M3-25 title style frame: 5 parallax SVG layers with drift, the VANGUARD silhouette on the
## ridge with a pulsing core glow, 3 fbm smoke layers, embers through the existing ParticleRenderer, and one
## distant flare. View only; its own RNG (never the sim's). Tiers: HIGH 3 smoke + embers + flare, MID 2 smoke,
## LOW 1 smoke, no embers, no flare. Reduce motion freezes drift, smoke, core pulse, embers and flare.

const EMBER_LIFE_S: float = 1.9
const EMBER_RATE: Array[float] = [26.0, 14.0, 0.0]
const EMBER_CAP: int = 160
const FLARE_GAP_S: Vector2 = Vector2(8.0, 20.0)
const FLARE_LEN_S: float = 0.9
const FROZEN_SMOKE_S: float = 41.0

var reduce_motion: bool = false
var tier: VisualQuality.Tier = VisualQuality.Tier.HIGH

var _rng := RandomNumberGenerator.new()
var _layers: Array[Sprite2D] = []
var _base_pos: PackedVector2Array = PackedVector2Array()
var _smoke: Array[ColorRect] = []
var _sil: Sprite2D = null
var _glow: Sprite2D = null
var _embers: ParticleRenderer = null
var _flare: Sprite2D = null
var _ember_acc: float = 0.0
var _flare_at: float = 0.0
var _flare_t: float = -1.0
var _flare_x: float = 1100.0


func build() -> void:
	_rng.seed = 7
	_flare_at = _rng.randf_range(FLARE_GAP_S.x, FLARE_GAP_S.y)
	for i: int in TitleFrameArt.LAYER_NAMES.size():
		var layer: Sprite2D = TitleFrameArt.sprite(TitleFrameArt.LAYER_NAMES[i], TitleFrameArt.LAYER_SCALE[i])
		layer.position = Vector2(0.0, TitleFrameArt.LAYER_Y[i])
		_layers.append(layer)
		_base_pos.append(layer.position)
	_smoke.append(TitleFrameArt.smoke_rect(0, Vector2(2160.0, TitleFrameArt.SMOKE_H[0]), _far_haze()))
	_smoke.append(TitleFrameArt.smoke_rect(1, Vector2(2160.0, TitleFrameArt.SMOKE_H[1]), _mid_smoke()))
	_smoke.append(TitleFrameArt.smoke_rect(2, Vector2(2160.0, TitleFrameArt.SMOKE_H[2]), _low_fog()))
	_build_cinder(_layers[3])
	_flare = Sprite2D.new()
	var halo: ArtSlot = ArtSlots.slot("fx_halo_soft")
	_flare.texture = ArtSlots.texture("fx_halo_soft")
	_flare.region_enabled = true
	_flare.region_rect = halo.frame_rect(0)
	_flare.material = TitleFrameArt.additive()
	_flare.modulate = Color(1.0, 0.7, 0.35, 0.0)
	_flare.scale = Vector2(9.0, 5.0)
	_flare.position = Vector2(_flare_x, 1330.0)
	_flare.visible = false
	_embers = ParticleRenderer.new()
	_embers.setup(EMBER_CAP)
	# draw order: sky, far spires, far haze, hulks, ridge + Cinder, mid smoke, embers, front ridge, low fog, flare
	add_child(_layers[0])
	add_child(_layers[1])
	add_child(_smoke[0])
	add_child(_layers[2])
	add_child(_layers[3])
	add_child(_smoke[1])
	add_child(_embers)
	add_child(_layers[4])
	add_child(_smoke[2])
	add_child(_flare)


func _build_cinder(ridge: Sprite2D) -> void:
	_sil = TitleFrameArt.sprite_pivot("sil_vanguard", TitleFrameArt.SIL_PIVOT, TitleFrameArt.SIL_SCALE)
	_sil.position = TitleFrameArt.PERCH
	ridge.add_child(_sil)
	_glow = TitleFrameArt.sprite_pivot("sil_vanguard_glow", TitleFrameArt.GLOW_PIVOT, TitleFrameArt.SIL_SCALE * 2.0)
	_glow.position = TitleFrameArt.PERCH
	_glow.material = TitleFrameArt.additive()
	ridge.add_child(_glow)


## Anchors the stage to the bottom of a viewport of `size` and centres it horizontally.
func layout(size: Vector2) -> void:
	position = Vector2((size.x - TitleFrameArt.STAGE_W) * 0.5, size.y - TitleFrameArt.REF_H)
	# a taller viewport than the 2400 reference would show a gap above the sky: stretch the sky upward
	var extra: float = maxf(size.y - TitleFrameArt.REF_H, 0.0)
	var sky: Sprite2D = _layers[0]
	_base_pos[0] = Vector2(0.0, -extra)
	sky.scale = Vector2(2.0, 2.0 + extra / 750.0)


func set_tier(t: VisualQuality.Tier) -> void:
	tier = t
	var order: Array[int] = [0, 1, 2]
	if t == VisualQuality.Tier.LOW:
		order = [1]
	elif t == VisualQuality.Tier.MID:
		order = [0, 1]
	for i: int in _smoke.size():
		_smoke[i].visible = order.has(i)
	_embers.visible = EMBER_RATE[int(t)] > 0.0
	_embers.clear()


func visible_smoke_count() -> int:
	var n: int = 0
	for s: ColorRect in _smoke:
		if s.visible:
			n += 1
	return n


func embers_active() -> bool:
	return _embers.visible and not reduce_motion


func ember_count() -> int:
	return _embers.live_count()


func flare_active() -> bool:
	return _flare_t >= 0.0


## Advances the view clock `t` (seconds since start) by `dt`.
func tick(t: float, dt: float) -> void:
	var tm: float = 0.0 if reduce_motion else t
	for i: int in _layers.size():
		var amp: float = TitleFrameArt.LAYER_AMP[i]
		var ph: float = TAU * tm / TitleFrameArt.LAYER_PERIOD[i]
		_layers[i].position = _base_pos[i] + Vector2(amp * sin(ph), amp * 0.12 * sin(ph * 1.7 + 1.0))
	var smoke_t: float = FROZEN_SMOKE_S if reduce_motion else t
	for s: ColorRect in _smoke:
		var m: ShaderMaterial = s.material as ShaderMaterial
		m.set_shader_parameter("u_time", smoke_t)
	var pulse: float = 0.5 if reduce_motion else 0.5 + 0.5 * sin(TAU * t / 2.6)
	_glow.modulate = Color(1.0, 1.0, 1.0, 0.72 + 0.28 * pulse)
	_glow.scale = Vector2.ONE * TitleFrameArt.SIL_SCALE * 2.0 * (1.0 + 0.04 * pulse)
	_tick_embers(t, dt)
	_tick_flare(t, dt)


func _tick_embers(t: float, dt: float) -> void:
	_embers.set_time(t)
	if embers_active():
		_ember_acc += EMBER_RATE[int(tier)] * dt
		while _ember_acc >= 1.0:
			_ember_acc -= 1.0
			_spawn_ember(t)
	_embers.flush()


func _spawn_ember(t: float) -> void:
	var pos := Vector2(_rng.randf_range(0.0, TitleFrameArt.STAGE_W), _rng.randf_range(1620.0, 1960.0))
	var vel := Vector2(_rng.randf_range(-24.0, 46.0), -_rng.randf_range(110.0, 230.0))
	var size := Vector2(_rng.randf_range(9.0, 15.0), 2.5)
	var color := Color(1.0, _rng.randf_range(0.45, 0.7), 0.12, _rng.randf_range(0.7, 0.95))
	var kind: int = ParticlePack.KIND_EMBER_A + _rng.randi_range(0, 1)
	var pool: ParticlePool = _embers.additive
	var slot: int = pool.emit(pos, vel, t, EMBER_LIFE_S, size, color, kind)
	if slot < 0:
		push_error("title frame: ember emit failed")


func _tick_flare(t: float, dt: float) -> void:
	var allowed: bool = tier != VisualQuality.Tier.LOW and not reduce_motion
	if _flare_t >= 0.0:
		_flare_t += dt
		var u: float = _flare_t / FLARE_LEN_S
		if u >= 1.0 or not allowed:
			_end_flare(t)
			return
		var env: float = (u / 0.12) if u < 0.12 else pow(1.0 - (u - 0.12) / 0.88, 2.0)
		_apply_flare(env)
	elif allowed and t >= _flare_at:
		start_flare()


func start_flare() -> void:
	_flare_t = 0.0
	_flare_x = _rng.randf_range(700.0, 1500.0)
	_flare.position = Vector2(_flare_x, 1330.0)
	_flare.visible = true


func _end_flare(t: float) -> void:
	_flare_t = -1.0
	_flare.visible = false
	_apply_flare(0.0)
	_flare_at = t + _rng.randf_range(FLARE_GAP_S.x, FLARE_GAP_S.y)


func _apply_flare(env: float) -> void:
	var c: Color = _flare.modulate
	c.a = 0.85 * env
	_flare.modulate = c
	# faint ground light change: the sky and the ridges brighten with the flash
	_layers[0].modulate = Color(1.0 + 0.45 * env, 1.0 + 0.35 * env, 1.0 + 0.2 * env, 1.0)
	_layers[3].modulate = Color(1.0 + 0.25 * env, 1.0 + 0.2 * env, 1.0 + 0.1 * env, 1.0)


func _far_haze() -> Dictionary:
	return {
		"density": 0.95,
		"noise_scale": 1.7,
		"drift": Vector2(0.010, -0.003),
		"additive": 0.12,
		"edge_lo": 0.4,
		"edge_hi": 0.66,
		"col_dark": Color(0.1, 0.06, 0.045),
		"col_warm": Color(1.0, 0.45, 0.1),
		"warm_y": 0.85,
		"warm_amount": 0.8,
		"fade_top": 0.4,
		"fade_bottom": 0.25,
	}


func _mid_smoke() -> Dictionary:
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


func _low_fog() -> Dictionary:
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
