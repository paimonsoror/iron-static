class_name ArenaBackground
extends Node2D
## Static arena backdrop (GDD 07 section 5.3): void fill of the battle area, faint polar
## grid (spokes every 30 degrees, rings every 10 m up to the arena edge) and brighter range
## rings at 10/20/30 m. One _draw, redrawn only when the layout or optic range changes.
## Local space: origin = Cinder; `battle_rect` is given in local pixels.

const RING_STEP_M: float = 10.0
const RANGE_RINGS_M: Array[float] = [10.0, 20.0, 30.0]
const SPOKES: int = 12
const RING_POINTS: int = 96
const VIGNETTE_STEPS: int = 6
const VIGNETTE_PX: float = 160.0

var _px_per_m: float = 28.0
var _arena_radius_m: float = 52.0
var _optic_range_m: float = 0.0
var _rect := Rect2(-540.0, -538.0, 1080.0, 1076.0)


## `rect` is the battle area in this node's local pixels.
func setup(px_per_m: float, arena_radius_m: float, rect: Rect2) -> void:
	_px_per_m = px_per_m
	_arena_radius_m = arena_radius_m
	_rect = rect
	queue_redraw()


## 0 hides the optic range ring.
func set_optic_range(range_m: float) -> void:
	if is_equal_approx(range_m, _optic_range_m):
		return
	_optic_range_m = range_m
	queue_redraw()


func _draw() -> void:
	draw_rect(_rect, Palette.VOID)
	var arena_px: float = _arena_radius_m * _px_per_m
	var faint := Color(Palette.GRID, 1.0)
	for k: int in SPOKES:
		var dir: Vector2 = Vector2.from_angle(TAU * float(k) / float(SPOKES))
		draw_line(Vector2.ZERO, dir * arena_px, faint, 2.0)
	var rings: int = floori(_arena_radius_m / RING_STEP_M)
	for i: int in range(1, rings + 1):
		var r: float = float(i) * RING_STEP_M * _px_per_m
		draw_arc(Vector2.ZERO, r, 0.0, TAU, RING_POINTS, faint, 2.0, true)
	var edge := Color(Palette.RED_HAZE.lerp(Palette.CRITICAL, 0.35), 0.8)
	draw_arc(Vector2.ZERO, arena_px, 0.0, TAU, RING_POINTS * 2, edge, 3.0, true)
	var ring_col := Color(Palette.AMBER_DIM, 0.45)
	for m: float in RANGE_RINGS_M:
		draw_arc(Vector2.ZERO, m * _px_per_m, 0.0, TAU, RING_POINTS, ring_col, 2.0, true)
	if _optic_range_m > 0.0:
		var optic := Color(Palette.AMBER, 0.35)
		draw_arc(Vector2.ZERO, _optic_range_m * _px_per_m, 0.0, TAU, RING_POINTS, optic, 2.0, true)
	_draw_vignette()


## Dark bands at the battle-area edges (stacked translucent rects, cheap and static).
func _draw_vignette() -> void:
	var step: float = VIGNETTE_PX / float(VIGNETTE_STEPS)
	for i: int in VIGNETTE_STEPS:
		var a: float = 0.35 * (1.0 - float(i) / float(VIGNETTE_STEPS))
		var col := Color(0.0, 0.0, 0.0, a / float(VIGNETTE_STEPS) * 2.0)
		var inset: float = step * float(i)
		var r: Rect2 = _rect.grow(-inset)
		draw_rect(Rect2(r.position, Vector2(r.size.x, step)), col)
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - step), Vector2(r.size.x, step)), col)
		draw_rect(Rect2(r.position, Vector2(step, r.size.y)), col)
		draw_rect(Rect2(Vector2(r.end.x - step, r.position.y), Vector2(step, r.size.y)), col)
