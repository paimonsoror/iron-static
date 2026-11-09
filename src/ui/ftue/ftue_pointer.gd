class_name FtuePointer
extends Control
## The FTUE pointer (M4-26): an amber outline around a target rect and an arrow that points at it from above (or from
## below when there is no room above). With motion the arrow bobs and the outline pulses; reduce motion replaces
## both with a static marker (full-strength outline, arrow at rest) and stops processing. Draws only; ignores input.

const OUTLINE_W: float = 6.0
const PAD: float = 10.0
const ARROW_W: float = 84.0
const ARROW_H: float = 72.0
const GAP: float = 8.0
const BOB_PX: float = 18.0
const BOB_HZ: float = 1.5
const PULSE_HZ: float = 1.0

## Set true to force reduce motion (it is also read from `Game.visual.reduce_motion`).
var reduce_motion: bool = false:
	set(value):
		reduce_motion = value
		_sync_processing()

var _target: Rect2 = Rect2()
var _has_target: bool = false
var _from_above: bool = true
var _tip_x: float = NAN
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)


## Arrow offset toward the target at time `t` (0 at rest); always 0 with reduce motion.
static func bob_offset(t: float, reduced: bool) -> float:
	if reduced:
		return 0.0
	return BOB_PX * (0.5 + 0.5 * sin(TAU * BOB_HZ * t))


## Outline opacity at time `t`: 1 with reduce motion, else a slow pulse between 0.55 and 1.
static func outline_alpha(t: float, reduced: bool) -> float:
	if reduced:
		return 1.0
	return 0.775 + 0.225 * sin(TAU * PULSE_HZ * t)


## Points at `rect` (this control's coordinates); `from_above` puts the arrow above the rect pointing down. `tip_x`
## (NAN = the rect's center) moves the arrow along the rect to a blank spot so it covers no text (M4-27).
func point_at(rect: Rect2, from_above: bool, tip_x: float = NAN) -> void:
	_target = rect
	_from_above = from_above
	_tip_x = tip_x
	_has_target = true
	_sync_processing()
	queue_redraw()


func clear() -> void:
	_has_target = false
	_sync_processing()
	queue_redraw()


func has_target() -> bool:
	return _has_target


func target_rect() -> Rect2:
	return _target


func is_animated() -> bool:
	return _has_target and not _reduced()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if not _has_target:
		return
	var red: bool = _reduced()
	var col: Color = Palette.AMBER_GLOW
	var edge: Color = Color(col, outline_alpha(_t, red))
	draw_rect(_target.grow(PAD), edge, false, OUTLINE_W)
	var bob: float = bob_offset(_t, red)
	var cx: float = _target.get_center().x if is_nan(_tip_x) else _tip_x
	var tip_y: float
	var base_y: float
	if _from_above:
		tip_y = _target.position.y - PAD - GAP - BOB_PX + bob
		base_y = tip_y - ARROW_H
	else:
		tip_y = _target.end.y + PAD + GAP + BOB_PX - bob
		base_y = tip_y + ARROW_H
	var pts := PackedVector2Array(
		[Vector2(cx, tip_y), Vector2(cx - ARROW_W * 0.5, base_y), Vector2(cx + ARROW_W * 0.5, base_y)]
	)
	draw_colored_polygon(pts, Color(Palette.AMBER, 0.95))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Palette.AMBER_GLOW, 3.0)


func _reduced() -> bool:
	return reduce_motion or Game.visual.reduce_motion


func _sync_processing() -> void:
	if is_inside_tree():
		set_process(is_animated())
