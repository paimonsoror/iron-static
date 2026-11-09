class_name TitleFx
extends Node2D
## The art stage of the title: the parallax layers (`TitleParallax`) with up to 3 fbm smoke layers, embers through
## the existing ParticleRenderer and one distant flare. View only; its own RNG (never the sim's). Tiers: HIGH 3 smoke
## + embers + flare, MID 2 smoke + fewer embers, LOW 1 smoke and nothing else animated but drift. Reduce motion
## freezes drift, smoke, core pulse, embers and flare.

const EMBER_LIFE_S: float = 1.9
const EMBER_CAP: int = 160
const FLARE_GAP_S: Vector2 = Vector2(8.0, 20.0)
const FLARE_LEN_S: float = 0.9
const FROZEN_SMOKE_S: float = 41.0
const FLARE_Y: float = 1330.0

var reduce_motion: bool = false
var tier: VisualQuality.Tier = VisualQuality.Tier.HIGH
var parallax := TitleParallax.new()

var _rng := RandomNumberGenerator.new()
var _smoke: Array[ColorRect] = []
var _embers: ParticleRenderer = null
var _flare: Sprite2D = null
var _ember_acc: float = 0.0
var _flare_at: float = 0.0
var _flare_t: float = -1.0


func build() -> void:
	_rng.seed = 7
	_flare_at = _rng.randf_range(FLARE_GAP_S.x, FLARE_GAP_S.y)
	parallax.build()
	_smoke.append(TitleArt.smoke_rect(0, TitleArt.far_haze()))
	_smoke.append(TitleArt.smoke_rect(1, TitleArt.mid_smoke()))
	_smoke.append(TitleArt.smoke_rect(2, TitleArt.low_fog()))
	_flare = Sprite2D.new()
	var halo: ArtSlot = ArtSlots.slot("fx_halo_soft")
	_flare.texture = ArtSlots.texture("fx_halo_soft")
	_flare.region_enabled = true
	_flare.region_rect = halo.frame_rect(0)
	_flare.material = TitleArt.additive()
	_flare.modulate = Color(1.0, 0.7, 0.35, 0.0)
	_flare.scale = Vector2(9.0, 5.0)
	_flare.position = Vector2(1100.0, FLARE_Y)
	_flare.visible = false
	_embers = ParticleRenderer.new()
	_embers.setup(EMBER_CAP)
	var ly: Array[Sprite2D] = parallax.layers
	# draw order: sky, far spires, far haze, hulks, ridge + hero, mid smoke, embers, front ridge, low fog, flare
	add_child(ly[0])
	add_child(ly[1])
	add_child(_smoke[0])
	add_child(ly[2])
	add_child(ly[3])
	add_child(_smoke[1])
	add_child(_embers)
	add_child(ly[4])
	add_child(_smoke[2])
	add_child(_flare)


func set_frame(frame_id: String) -> void:
	parallax.set_frame(frame_id)


func frame_id_shown() -> String:
	return parallax.frame_id_shown


## Anchors the stage to the bottom of a view of `size` and centres it horizontally.
func layout(size: Vector2) -> void:
	position = Vector2((size.x - TitleArt.STAGE_W) * 0.5, size.y - TitleArt.REF_H)
	parallax.stretch_sky(maxf(size.y - TitleArt.REF_H, 0.0))


func set_tier(t: VisualQuality.Tier) -> void:
	tier = t
	var shown: Array[int] = TitleModel.smoke_layers(t)
	for i: int in _smoke.size():
		_smoke[i].visible = shown.has(i)
	_embers.visible = TitleModel.embers_enabled(t)
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


func has_emitter() -> bool:
	return _embers.visible


func flare_active() -> bool:
	return _flare_t >= 0.0


## Advances the view clock `t` (seconds since start) by `dt`.
func tick(t: float, dt: float) -> void:
	parallax.tick(t, reduce_motion)
	var smoke_t: float = FROZEN_SMOKE_S if reduce_motion else t
	for s: ColorRect in _smoke:
		var m: ShaderMaterial = s.material as ShaderMaterial
		m.set_shader_parameter("u_time", smoke_t)
	_tick_embers(t, dt)
	_tick_flare(t, dt)


func _tick_embers(t: float, dt: float) -> void:
	_embers.set_time(t)
	if embers_active():
		_ember_acc += TitleModel.EMBER_RATE[int(tier)] * dt
		while _ember_acc >= 1.0:
			_ember_acc -= 1.0
			_spawn_ember(t)
	_embers.flush()


func _spawn_ember(t: float) -> void:
	var pos := Vector2(_rng.randf_range(0.0, TitleArt.STAGE_W), _rng.randf_range(1620.0, 1960.0))
	var vel := Vector2(_rng.randf_range(-24.0, 46.0), -_rng.randf_range(110.0, 230.0))
	var size := Vector2(_rng.randf_range(9.0, 15.0), 2.5)
	var color := Color(1.0, _rng.randf_range(0.45, 0.7), 0.12, _rng.randf_range(0.7, 0.95))
	var kind: int = ParticlePack.KIND_EMBER_A + _rng.randi_range(0, 1)
	var pool: ParticlePool = _embers.additive
	var slot: int = pool.emit(pos, vel, t, EMBER_LIFE_S, size, color, kind)
	if slot < 0:
		push_error("title: ember emit failed")


func _tick_flare(t: float, dt: float) -> void:
	var allowed: bool = TitleModel.flare_enabled(tier, reduce_motion)
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
	_flare.position = Vector2(_rng.randf_range(700.0, 1500.0), FLARE_Y)
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
	parallax.apply_flare(env)
