class_name BeamRenderer
extends Node2D
## Hitscan beam lines (GDD 02 section 2, GDD 07 section 5.1/5.2): on each SHOT_FIRED event a
## beam from the emitter to the target is stored in a fixed pool of 16 and fades over 80 ms
## of wall time. Core 3 px `Palette.LASER_CORE`, glow 8 px `Palette.LASER_GLOW`, additive blend.
## Local space: origin = Cinder, sim meters * px_per_m (same convention as EnemyRenderer).
##
## Target position: read from the enemy store when the event is drained. Released slots keep
## their last position (the store never clears it), so a target killed by its own shot still
## gets a correct end point. Only if the slot was reused by a new spawn within the same frame
## (needs several ticks per frame) would the end be wrong; accepted for M1 (impl).

const MAX_BEAMS: int = 16
const FADE_S: float = 0.08
const CORE_PX: float = 3.0
const GLOW_PX: float = 8.0
const GLOW_ALPHA: float = 0.6

var _start := PackedVector2Array()
var _end := PackedVector2Array()
var _born := PackedFloat32Array()
var _next: int = 0
var _now_s: float = 0.0
var _events := EventCursor.new()
var _was_active: bool = false


func _init() -> void:
	var ok: bool = _start.resize(MAX_BEAMS) == OK
	ok = ok and _end.resize(MAX_BEAMS) == OK
	ok = ok and _born.resize(MAX_BEAMS) == OK
	if not ok:
		push_error("BeamRenderer: resize failed")
	for i: int in MAX_BEAMS:
		_born[i] = -1000.0
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


## Call when binding to a world mid-run so old events are not drawn.
func bind(world: SimWorld) -> void:
	_events.sync_to(world.events)


## Consumes new SHOT_FIRED events and redraws. `now_s` is monotonic wall time (seconds),
## `emitter_px` the beam start in local pixels.
func update(world: SimWorld, now_s: float, px_per_m: float, emitter_px: Vector2) -> void:
	_now_s = now_s
	var store: EnemyStore = world.enemies
	while _events.poll(world.events) > 0:
		for i: int in _events.count:
			if _events.kind_at(i) != SimEventKind.SHOT_FIRED:
				continue
			var idx: int = _events.a_at(i)
			if idx < 0 or idx >= store.high_water:
				continue
			var target := Vector2(store.pos_x[idx], store.pos_y[idx]) * px_per_m
			add_beam(emitter_px, target, now_s)
	var active: bool = _any_active()
	if active or _was_active:
		queue_redraw()
	_was_active = active


## Adds a beam to the ring (overwrites the oldest when 16 are in use).
func add_beam(start: Vector2, end: Vector2, now_s: float) -> void:
	_start[_next] = start
	_end[_next] = end
	_born[_next] = now_s
	_next = (_next + 1) % MAX_BEAMS


## Linear fade 1 -> 0 over FADE_S; 0 for unborn or expired beams.
static func fade_alpha(age_s: float) -> float:
	if age_s < 0.0 or age_s >= FADE_S:
		return 0.0
	return 1.0 - age_s / FADE_S


func _any_active() -> bool:
	for i: int in MAX_BEAMS:
		if fade_alpha(_now_s - _born[i]) > 0.0:
			return true
	return false


func _draw() -> void:
	for i: int in MAX_BEAMS:
		var f: float = fade_alpha(_now_s - _born[i])
		if f <= 0.0:
			continue
		var glow: Color = Palette.LASER_GLOW
		glow.a = GLOW_ALPHA * f
		var core: Color = Palette.LASER_CORE
		core.a = f
		draw_line(_start[i], _end[i], glow, GLOW_PX)
		draw_line(_start[i], _end[i], core, CORE_PX)
