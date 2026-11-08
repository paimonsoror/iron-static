class_name CinderView
extends Node2D
## Cinder drawn procedurally (GDD 07 section 5.6, GDD 01 section 3). Pure observer: the
## battle view feeds it band/hp/aim from the sim each frame via set_state(). Origin = center.
## Layers back to front: frame ribs, skin wedge ring, chest core, emitter ring, visor,
## shoulder emitter, integrity ring. Range rings belong to the battle view.
## Wedge fills are polygons of identical state, so the canvas batcher merges them.

const WEDGE_ARC_STEPS: int = 5
const WEDGE_GAP: float = 0.03
const INTEGRITY_POINTS: int = 64
const PULSE_HZ: float = 1.0
const SCAN_PERIOD_S: float = 8.0
const WHITE_HOT := Color(1.0, 0.96, 0.88)

## Outer radius of the emitter ring in pixels (battle view sets it from the visual scale).
var radius_px: float = 110.0:
	set(value):
		radius_px = maxf(value, 8.0)
		_rebuild_geometry()
		queue_redraw()

var _hp_frac: float = 1.0
var _band: int = 0
var _aim: float = -PI * 0.5
var _time_s: float = 0.0
var _wedge_polys: Array[PackedVector2Array] = []
var _ribs := PackedVector2Array()


func _init() -> void:
	_rebuild_geometry()


## Feed the latest sim values. `aim_angle` radians (0 = +x, y down), `time_s` view clock.
func set_state(hp_frac: float, band: int, aim_angle: float, time_s: float) -> void:
	_hp_frac = clampf(hp_frac, 0.0, 1.0)
	_band = clampi(band, 0, 3)
	_aim = aim_angle
	_time_s = time_s
	queue_redraw()


func _rebuild_geometry() -> void:
	_wedge_polys.clear()
	_ribs.clear()
	var r_in: float = radius_px * 0.5
	var r_out: float = radius_px * 0.92
	var step: float = TAU / float(CinderWedges.WEDGE_COUNT)
	for i: int in CinderWedges.WEDGE_COUNT:
		var a0: float = -PI * 0.5 + step * float(i) + WEDGE_GAP
		var a1: float = -PI * 0.5 + step * float(i + 1) - WEDGE_GAP
		var poly := PackedVector2Array()
		for k: int in WEDGE_ARC_STEPS + 1:
			poly.append(Vector2.from_angle(lerpf(a0, a1, float(k) / WEDGE_ARC_STEPS)) * r_out)
		for k: int in WEDGE_ARC_STEPS + 1:
			var t: float = 1.0 - float(k) / WEDGE_ARC_STEPS
			poly.append(Vector2.from_angle(lerpf(a0, a1, t)) * r_in)
		_wedge_polys.append(poly)
		var rib_dir: Vector2 = Vector2.from_angle(-PI * 0.5 + step * float(i))
		_ribs.append(rib_dir * radius_px * 0.3)
		_ribs.append(rib_dir * radius_px * 0.95)


func _draw() -> void:
	var r: float = radius_px
	var pulse: float = 0.5 + 0.5 * sin(TAU * PULSE_HZ * _time_s)
	var hot: bool = _band >= 3
	_draw_frame(r, pulse, hot)
	_draw_wedges(r)
	_draw_core(r, pulse, hot)
	_draw_emitters(r)
	_draw_visor(r)
	_draw_integrity(r)


func _draw_frame(r: float, pulse: float, hot: bool) -> void:
	var col: Color = Palette.FRAME
	if hot:
		col = Palette.FRAME.lerp(WHITE_HOT, 0.65 + 0.35 * pulse)
	draw_multiline(_ribs, col, 3.0, true)
	draw_arc(Vector2.ZERO, r * 0.95, 0.0, TAU, 48, col, 3.0, true)
	draw_arc(Vector2.ZERO, r * 0.5, 0.0, TAU, 36, col, 2.0, true)
	# Slow scan sweep, once per SCAN_PERIOD_S.
	var sweep: float = TAU * fmod(_time_s, SCAN_PERIOD_S) / SCAN_PERIOD_S
	var dim := Color(Palette.AMBER_DIM, 0.45)
	draw_line(Vector2.ZERO, Vector2.from_angle(sweep) * r * 1.2, dim, 1.0)


func _draw_wedges(r: float) -> void:
	var states: PackedInt32Array = CinderWedges.states(_band)
	var flicker: float = 0.8 + 0.2 * sin(_time_s * 23.0) if _band == 1 or _band == 2 else 1.0
	for i: int in CinderWedges.WEDGE_COUNT:
		var s: int = states[i]
		if s == CinderWedges.GONE:
			continue
		var col: Color = Palette.SKIN if s == CinderWedges.INTACT else Palette.CHAR
		if s == CinderWedges.CHARRED:
			col.a = flicker
		draw_colored_polygon(_wedge_polys[i], col)
	draw_arc(Vector2.ZERO, r * 0.92, 0.0, TAU, 48, Color(Palette.AMBER_DIM, 0.6), 1.0, true)


func _draw_core(r: float, pulse: float, hot: bool) -> void:
	var size: float = r * 0.27 * (1.0 + 0.08 * pulse)
	var hex := PackedVector2Array()
	for k: int in 6:
		hex.append(Vector2.from_angle(PI / 6.0 + TAU * float(k) / 6.0) * size)
	var fill: Color = Palette.CORE.lerp(Palette.AMBER_GLOW, 1.0 - pulse)
	if hot:
		fill = WHITE_HOT
	draw_colored_polygon(hex, fill)
	var outline: Color = Palette.AMBER
	if hot:
		outline = Palette.CRITICAL
	var closed: PackedVector2Array = hex.duplicate()
	closed.append(hex[0])
	draw_polyline(closed, outline, 2.0, true)
	if hot:
		# Cracked outline: jagged dark fissures across the core.
		var crack := PackedVector2Array(
			[
				Vector2(-size * 0.9, -size * 0.2),
				Vector2(-size * 0.2, 0.0),
				Vector2(size * 0.1, -size * 0.5),
				Vector2(size * 0.9, size * 0.1)
			]
		)
		draw_polyline(crack, Palette.CHAR, 2.0, true)


func _draw_emitters(r: float) -> void:
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(Palette.FRAME, 0.55), 2.0, true)
	for k: int in 3:
		var p: Vector2 = Vector2.from_angle(_aim + TAU * float(k) / 3.0) * r
		var active: bool = k == 0
		draw_circle(p, r * 0.1, Palette.EMITTER if active else Palette.AMBER_GLOW)
	# Asymmetric left shoulder emitter: fixed to the screen, not the rotating ring.
	var shoulder: Vector2 = Vector2(-r * 1.18, -r * 0.18)
	draw_line(Vector2(-r * 0.9, -r * 0.1), shoulder, Palette.FRAME, 3.0, true)
	draw_circle(shoulder, r * 0.13, Palette.AMBER)
	draw_circle(shoulder, r * 0.06, Palette.CORE)


func _draw_visor(r: float) -> void:
	draw_arc(Vector2.ZERO, r * 0.7, _aim - 0.4, _aim + 0.4, 12, Palette.AMBER_GLOW, 2.0, true)


func _draw_integrity(r: float) -> void:
	var ring_r: float = r * 1.32
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, INTEGRITY_POINTS, Palette.GRID, 3.0, true)
	if _hp_frac <= 0.0:
		return
	var col: Color = _integrity_color(_hp_frac)
	var start: float = -PI * 0.5
	draw_arc(Vector2.ZERO, ring_r, start, start + TAU * _hp_frac, INTEGRITY_POINTS, col, 3.0, true)


## Teal (full) to amber (half) to red (quarter and below).
static func _integrity_color(hp_frac: float) -> Color:
	if hp_frac >= 0.5:
		return Palette.AMBER.lerp(Palette.TEAL, (hp_frac - 0.5) / 0.5)
	return Palette.CRITICAL.lerp(Palette.AMBER, clampf((hp_frac - 0.25) / 0.25, 0.0, 1.0))
