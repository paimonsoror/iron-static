class_name ArenaBackground
extends Node2D
## Arena backdrop (art bible 6.7, V1-08): the static floor art plus analytic grid, sweep, pulses and optic ring in
## ONE opaque full-rect pass (`arena_fx.gdshader`, below the sprites), and scanlines, vignette and the low-HP haze
## in ONE premultiplied pass (`arena_overlay.gdshader`, above the sprites; this node adds it as the last child of
## its parent so Cinder and the beams sit under it). Plus 24 ambient motes on HIGH. Local space: origin = Cinder.
## Decision (impl): scanlines and vignette DO overlay the sprites (6% rows, 20% edge darken, no blur), so the
## picture reads as one screen; the grid never draws over units.
## Cost: 2 draws (3 with motes), no per-frame allocation; uniforms are written only when their value changes.

const FLOOR_SLOT: String = "arena_floor"
const MOTE_COUNT: int = 24
const FX_SHADER: Shader = preload("res://assets/shaders/arena_fx.gdshader")
const OVERLAY_SHADER: Shader = preload("res://assets/shaders/arena_overlay.gdshader")

var _px_per_m: float = ViewMath.px_per_m(1080.0)
var _arena_radius_m: float = 52.0
var _optic_range_m: float = 0.0
var _rect := Rect2(-540.0, -538.0, 1080.0, 1076.0)
var _visual: VisualSettings = VisualSettings.new()
var _floor: ColorRect
var _overlay: ColorRect
var _motes: CPUParticles2D
var _fx_mat: ShaderMaterial
var _ov_mat: ShaderMaterial
var _lh_base: float = 0.0
var _lh_swing: float = 0.0
var _snap: bool = false
var _last_ms: int = Time.get_ticks_msec()
var _fx_cache: Dictionary = {}
var _ov_cache: Dictionary = {}


func _ready() -> void:
	_fx_mat = ShaderMaterial.new()
	_fx_mat.shader = FX_SHADER
	_fx_mat.set_shader_parameter("floor_tex", ArtSlots.texture(FLOOR_SLOT))
	_floor = _make_rect(_fx_mat)
	add_child(_floor)
	_motes = _make_motes()
	add_child(_motes)
	_ov_mat = ShaderMaterial.new()
	_ov_mat.shader = OVERLAY_SHADER
	_overlay = _make_rect(_ov_mat)
	# The parent is still setting up its children: attach after it, as its last (topmost) child.
	get_parent().add_child.call_deferred(_overlay)
	tree_exiting.connect(_overlay.queue_free)
	_apply_layout()
	apply_state(0.0, 0, 0)


## `rect` is the battle area in this node's local pixels.
func setup(px_per_m: float, arena_radius_m: float, rect: Rect2) -> void:
	_px_per_m = px_per_m
	_arena_radius_m = arena_radius_m
	_rect = rect
	if _fx_mat != null:
		_apply_layout()
		apply_state(0.0, 0, 0)


## Injects the visual settings (tier toggles, reduce motion, scanline intensity). Read every frame, no signals.
func setup_visual(settings: VisualSettings) -> void:
	_visual = settings


## 0 hides the optic range ring.
func set_optic_range(range_m: float) -> void:
	if is_equal_approx(range_m, _optic_range_m):
		return
	_optic_range_m = range_m
	if _fx_mat != null:
		_set_fx(&"optic_range_px", ArenaFxParams.optic_px(range_m, _px_per_m))


## Per-frame update. `clock_s` is the view clock (sim time, freezes with the sim), `band` Cinder's integrity band,
## `alive` the live enemy count (density fade of the grid).
func apply_state(clock_s: float, band: int, alive: int) -> void:
	if _fx_mat == null:
		return
	var sweep_on: bool = ArenaFxParams.sweep_enabled(_visual)
	var pulse_on: bool = ArenaFxParams.range_pulse_enabled(_visual)
	var beat: bool = ArenaFxParams.pulse_allowed(_visual)
	# Haze: eased steady level (150 ms, wall clock so it also settles while the sim is paused) plus the heartbeat swing.
	var now_ms: int = Time.get_ticks_msec()
	var ease_dt: float = clampf(float(now_ms - _last_ms) / 1000.0, 0.0, 0.1)
	_last_ms = now_ms
	if _snap:
		_snap = false
		ease_dt = 10.0
	_lh_base = ArenaFxParams.ease_step(_lh_base, ArenaFxParams.low_hp_base(band, beat), ease_dt)
	_lh_swing = ArenaFxParams.ease_step(_lh_swing, ArenaFxParams.low_hp_swing(band, beat), ease_dt)
	var low_hp: float = ArenaFxParams.low_hp_intensity(_lh_base, _lh_swing, HeartbeatModel.value(clock_s))
	_set_fx(&"sweep_enabled", ArenaFxParams.flag(sweep_on))
	_set_fx(&"pulse_enabled", ArenaFxParams.flag(pulse_on))
	_set_fx(&"density", ArenaFxParams.density_fade(alive))
	_set_fx(&"sweep_phase", ArenaFxParams.sweep_phase(clock_s) if sweep_on else 0.0)
	_set_fx(&"pulse_phase", ArenaFxParams.pulse_phase(clock_s) if pulse_on else 0.0)
	_set_ov(&"scan_alpha", _visual.effective_scanlines())
	_set_ov(&"low_hp", snappedf(low_hp, 0.001))
	_apply_motes()


func _apply_layout() -> void:
	_floor.position = _rect.position
	_floor.size = _rect.size
	_overlay.position = _rect.position
	_overlay.size = _rect.size
	_set_fx(&"rect_px", _rect.size)
	_set_fx(&"rect_origin_px", _rect.position)
	_set_fx(&"px_per_m", _px_per_m)
	_set_fx(&"art_scale", ArenaFxParams.art_scale(_px_per_m))
	_set_fx(&"arena_radius_px", ViewMath.map_dist(_arena_radius_m, _px_per_m))
	_set_fx(&"optic_range_px", ArenaFxParams.optic_px(_optic_range_m, _px_per_m))
	_set_ov(&"rect_px", _rect.size)
	_motes.position = _rect.get_center()
	_motes.emission_rect_extents = _rect.size * 0.5


func _apply_motes() -> void:
	var want: bool = _visual.quality.motes and not _visual.reduce_motion
	if _motes.emitting != want:
		_motes.emitting = want
		_motes.visible = want


func _set_fx(uniform: StringName, value: Variant) -> void:
	if _fx_cache.has(uniform) and _fx_cache[uniform] == value:
		return
	_fx_cache[uniform] = value
	_fx_mat.set_shader_parameter(uniform, value)


func _set_ov(uniform: StringName, value: Variant) -> void:
	if _ov_cache.has(uniform) and _ov_cache[uniform] == value:
		return
	_ov_cache[uniform] = value
	_ov_mat.set_shader_parameter(uniform, value)


func _make_rect(mat: ShaderMaterial) -> ColorRect:
	var r := ColorRect.new()
	r.material = mat
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = Color.WHITE
	return r


func _make_motes() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = MOTE_COUNT
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.direction = Vector2.UP
	p.spread = 25.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 16.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray(
		[Color(Palette.AMBER_DIM, 0.0), Color(Palette.AMBER_DIM, 0.18), Color(Palette.FRAME, 0.0)]
	)
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	p.color_ramp = ramp
	return p


## The next `apply_state` jumps the haze to its target instead of easing (scene start, captures, tests).
func snap_haze() -> void:
	_snap = true
