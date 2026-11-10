class_name BeamScorch
extends Node2D
## Faint scorch lines on the arena floor (R1-06): one warm line from the emitter to the target per shot, fading over
## about 1 s (`BeamAfterglow`). Sits between the background and the enemies, normal blend. A fixed ring of
## `RING` slots; the live count is capped by the quality tier (HIGH 8, MID 4, LOW 2) and the oldest line is dropped
## first. `BeamRenderer.shoot` feeds it. View only.

const RING: int = 8

var visual: VisualSettings
## Lines added so far (tests).
var added: int = 0
## Width multiplier (the sprite factor) set by the battle view.
var px_scale: float = 1.0

var _start := PackedVector2Array()
var _end := PackedVector2Array()
var _born := PackedFloat32Array()
var _next: int = 0
var _now_s: float = 0.0
var _was_active: bool = false


func _init() -> void:
	var ok: bool = _start.resize(RING) == OK
	ok = ok and _end.resize(RING) == OK
	ok = ok and _born.resize(RING) == OK
	if not ok:
		push_error("BeamScorch: resize failed")
	for i: int in RING:
		_born[i] = -1000.0


## Adds one line (overwrites the oldest slot).
func add(start: Vector2, end: Vector2, now_s: float) -> void:
	_start[_next] = start
	_end[_next] = end
	_born[_next] = now_s
	_next = (_next + 1) % RING
	added += 1


func update(now_s: float) -> void:
	_now_s = now_s
	var active: bool = live_count(now_s) > 0
	if active or _was_active:
		queue_redraw()
	_was_active = active


## Lines drawn at `now_s`: alive and within the tier cap (newest first).
func live_count(now_s: float) -> int:
	return _live_slots(now_s).size()


func _calm() -> bool:
	return visual != null and visual.reduce_motion


func _tier() -> int:
	return VisualQuality.Tier.HIGH if visual == null or visual.quality == null else visual.quality.tier


func _live_slots(now_s: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var cap: int = BeamAfterglow.scorch_cap(_tier())
	var calm: bool = _calm()
	for k: int in RING:
		if out.size() >= cap:
			break
		var slot: int = posmod(_next - 1 - k, RING)
		if BeamAfterglow.scorch_alpha(now_s - _born[slot], calm) > 0.0:
			@warning_ignore("return_value_discarded")
			out.append(slot)
	return out


func _draw() -> void:
	var calm: bool = _calm()
	for slot: int in _live_slots(_now_s):
		var c: Color = BeamAfterglow.SCORCH_COLOR
		c.a = BeamAfterglow.scorch_alpha(_now_s - _born[slot], calm)
		draw_line(_start[slot], _end[slot], c, BeamAfterglow.SCORCH_PX * px_scale)
