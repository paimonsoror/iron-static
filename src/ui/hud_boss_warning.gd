class_name HudBossWarning
extends Control
## Boss warning layer of the HUD (M4-17; GDD 02 s15, 07 s2.1 `hud_boss_chip`). Two amber chevrons, drawn here so
## `hud.gd` stays small:
## - the chip: a small chevron beside the wave counter while `SimWorld.waves_until_boss()` is 1..3 (waves 7-9 for a
##   boss at 10; hidden on the boss wave itself),
## - the spawn-edge chevron: from `BOSS_WARNING` (45 ticks before the boss is due) until it is due, at the field
##   edge in the warned direction, pointing at Cinder.
## `BOSS_SPAWNED` raises `boss_arrived` (the HUD plays the banner). Events are read through a private `EventCursor`;
## nothing here writes the sim. Timing follows `world.tick`, so it is the same at every speed. Reduce motion: no
## pulse, the chevrons are steady. Never takes input.

signal boss_arrived

const CHIP_MAX_WAVES: int = 3
const CHIP_SIZE: float = 18.0
const EDGE_SIZE: float = 46.0
const EDGE_INSET_PX: float = 64.0
const PULSE_HZ: float = 2.5
const DIM_ALPHA: float = 0.45

var reduce_motion: bool = false

var _events: EventCursor = EventCursor.new()
var _world: SimWorld = null
var _chip_on: bool = false
var _chip_urgent: bool = false
var _chip_pos: Vector2 = Vector2.ZERO
var _warn_angle: int = -1
var _warn_until_tick: int = -1
var _edge_pos: Vector2 = Vector2.ZERO
var _edge_dir: Vector2 = Vector2.UP
var _pulse: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## The chip shows 1..3 waves before a boss wave (`waves_until` from `SimWorld.waves_until_boss()`, -1 = no bosses).
static func chip_visible(waves_until: int) -> bool:
	return waves_until >= 1 and waves_until <= CHIP_MAX_WAVES


## Where the spawn-edge chevron sits: the point of `field`'s border in sim direction `angle_idx` (a SinCosTable index,
## +x right, +y down, Cinder at the field centre), pulled `inset` px inward.
static func edge_point(field: Rect2, angle_idx: int, inset: float) -> Vector2:
	var dir: Vector2 = Vector2(SinCosTable.cos_i(angle_idx), SinCosTable.sin_i(angle_idx))
	var c: Vector2 = field.get_center()
	var half: Vector2 = field.size * 0.5 - Vector2(inset, inset)
	var tx: float = half.x / absf(dir.x) if absf(dir.x) > 0.0001 else INF
	var ty: float = half.y / absf(dir.y) if absf(dir.y) > 0.0001 else INF
	return c + dir * maxf(minf(tx, ty), 0.0)


func chip_shown() -> bool:
	return _chip_on


## True from `BOSS_WARNING` until the boss is due.
func edge_shown() -> bool:
	return _warn_angle >= 0


func warned_angle() -> int:
	return _warn_angle


func edge_position() -> Vector2:
	return _edge_pos


## Starts observing `world` (events already pushed are skipped) and clears any warning.
func bind(world: SimWorld) -> void:
	_world = world
	_events.sync_to(world.events)
	_warn_angle = -1
	_warn_until_tick = -1
	queue_redraw()


## Per rendered frame: drains events, refreshes the chip from the wave counter and places the chevrons.
## `field` is the open battle field in this control's pixels, `chip_anchor` the point right of the wave label.
func update(world: SimWorld, field: Rect2, chip_anchor: Vector2) -> void:
	if world != _world:
		bind(world)
	while _events.poll(world.events) > 0:
		for i: int in _events.count:
			_route(_events.kind_at(i), _events.a_at(i), _events.b_at(i), _events.tick_at(i))
	if _warn_angle >= 0 and world.tick >= _warn_until_tick:
		_warn_angle = -1
	var until: int = world.waves_until_boss()
	_chip_on = chip_visible(until) and not world.is_boss_wave(world.wave)
	_chip_urgent = until == 1
	_chip_pos = chip_anchor
	if _warn_angle >= 0:
		_edge_pos = edge_point(field, _warn_angle, EDGE_INSET_PX)
		_edge_dir = (field.get_center() - _edge_pos).normalized()
	_pulse = _phase(world.tick)
	queue_redraw()


func _route(kind: int, a: int, b: int, event_tick: int) -> void:
	match kind:
		SimEventKind.BOSS_WARNING:
			_warn_angle = a & SinCosTable.MASK
			_warn_until_tick = event_tick + maxi(b, 1)
		SimEventKind.BOSS_SPAWNED:
			_warn_angle = -1
			boss_arrived.emit()


func _phase(tick: int) -> float:
	if reduce_motion or Game.visual.reduce_motion:
		return 1.0
	var s: float = float(tick) / float(Ticks.TICK_RATE) * PULSE_HZ
	return lerpf(DIM_ALPHA, 1.0, 0.5 + 0.5 * sin(s * TAU))


func _draw() -> void:
	if _chip_on:
		var a: float = _pulse if _chip_urgent else 1.0
		_chevron(_chip_pos, Vector2.DOWN, CHIP_SIZE, Color(Palette.WARNING, a))
	if _warn_angle >= 0:
		_chevron(_edge_pos, _edge_dir, EDGE_SIZE, Color(Palette.WARNING, _pulse))
		_chevron(_edge_pos - _edge_dir * EDGE_SIZE * 0.7, _edge_dir, EDGE_SIZE, Color(Palette.WARNING, _pulse * 0.6))


## A chevron (V shape) of half-width `size` pointing along `dir`, tip at `at`.
func _chevron(at: Vector2, dir: Vector2, size: float, col: Color) -> void:
	var side: Vector2 = Vector2(-dir.y, dir.x)
	var back: Vector2 = at - dir * size * 0.7
	draw_polyline(PackedVector2Array([back + side * size, at, back - side * size]), col, maxf(size * 0.22, 3.0), true)
