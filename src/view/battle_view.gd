class_name BattleView
extends Node2D
## Battlefield assembly (TECH_ARCHITECTURE 1.4): arena backdrop, enemies/bolts, beams and
## Cinder, all placed at Cinder's screen position (center of the top 56% of the viewport).
## Pure observer: reads the SimWorld in render(), never writes it. The HUD and the bottom
## panel live in `Hud`, not here.
## Usage: add to the scene, `bind(world)` after creating a run, `render(alpha)` every frame.
## Cinder's aim angle follows the target of the latest SHOT_FIRED event (own EventCursor);
## it keeps the last angle between shots (initially straight up).

## View-only override of the displayed exposure band (debug overlay, M1-24); -1 shows the sim's band.
var band_override: int = -1
var _world: SimWorld
var _px_per_m: float = ViewMath.px_per_m(1080.0)
var _viewport_size := Vector2(1080.0, 1920.0)
var _aim: float = -PI * 0.5
var _events := EventCursor.new()

@onready var _background: ArenaBackground = $Background
@onready var _enemies: EnemyRenderer = $Enemies
@onready var _beams: BeamRenderer = $Beams
@onready var _cinder: CinderView = $Cinder


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)
	layout(get_viewport_rect().size)


## Recomputes scale and positions for a viewport size (also called on resize).
func layout(viewport_size: Vector2) -> void:
	_viewport_size = viewport_size
	_px_per_m = ViewMath.px_per_m(viewport_size.x)
	position = ViewMath.cinder_center(viewport_size)
	var rect: Rect2 = ViewMath.battle_rect(viewport_size)
	rect.position -= position
	var arena_m: float = 52.0
	if _world != null:
		arena_m = _world.config.tuning.arena_radius
	_background.setup(_px_per_m, arena_m, rect)
	_cinder.radius_px = _cinder_radius_m() * _px_per_m
	if _world != null:
		_setup_enemy_renderer()


## Starts observing `world` (skips events already pushed).
func bind(world: SimWorld) -> void:
	_world = world
	_events.sync_to(world.events)
	_beams.bind(world)
	_aim = -PI * 0.5
	layout(_viewport_size)


## Draws the world interpolated by `alpha` (accumulator / SimWorld.DT).
func render(alpha: float) -> void:
	if _world == null:
		return
	var now_s: float = Time.get_ticks_msec() / 1000.0
	_update_aim()
	var cinder: CinderState = _world.cinder
	var hp_frac: float = 0.0
	if cinder.max_hp > 0.0:
		hp_frac = cinder.hp / cinder.max_hp
	var band: int = cinder.band if band_override < 0 else band_override
	_cinder.set_state(hp_frac, band, _aim, now_s)
	_background.set_optic_range(_world.stats.optic_range)
	_enemies.render(_world, alpha)
	var emitter: Vector2 = Vector2.from_angle(_aim) * _cinder.radius_px
	_beams.update(_world, now_s, _px_per_m, emitter)


## Exposed for the debug overlay (M1-24) to override the displayed band.
func cinder_view() -> CinderView:
	return _cinder


func px_per_m() -> float:
	return _px_per_m


func _update_aim() -> void:
	var store: EnemyStore = _world.enemies
	while _events.poll(_world.events) > 0:
		for i: int in _events.count:
			if _events.kind_at(i) != SimEventKind.SHOT_FIRED:
				continue
			var idx: int = _events.a_at(i)
			if idx >= 0 and idx < store.high_water:
				_aim = atan2(store.pos_y[idx], store.pos_x[idx])


func _setup_enemy_renderer() -> void:
	var defs: Array[EnemyDef] = _world.config.enemies
	var radii := PackedFloat32Array()
	for def: EnemyDef in defs:
		radii.append(def.radius)
	_enemies.setup(_px_per_m, radii)


func _cinder_radius_m() -> float:
	if _world != null:
		return _world.config.tuning.cinder_radius
	return 2.0


func _on_viewport_resized() -> void:
	layout(get_viewport_rect().size)
