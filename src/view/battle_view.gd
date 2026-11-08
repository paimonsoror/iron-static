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
## View camera width in meters; 38.0 selects the old framing for comparison (call set_camera_width_m).
var camera_width_m: float = ViewMath.VIEW_CAMERA_WIDTH_M
var _world: SimWorld
var _px_per_m: float = ViewMath.px_per_m(1080.0)
var _viewport_size := Vector2(1080.0, 1920.0)
var _aim: float = -PI * 0.5
var _events := EventCursor.new()
var _particles: ParticleRenderer
var _fx := FxSpawner.new()

@onready var _background: ArenaBackground = $Background
@onready var _enemies: EnemyRenderer = $Enemies
@onready var _beams: BeamRenderer = $Beams
@onready var _cinder: CinderView = $Cinder


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)
	# Looked up by path: scripts that compile this class without autoloads (capture tools) must still load.
	var settings: VisualSettings = _game_visual()
	_cinder.visual = settings
	_beams.visual = settings
	if settings != null:
		_background.setup_visual(settings)
	_setup_particles(settings)
	layout(get_viewport_rect().size)


## Recomputes scale and positions for a viewport size (also called on resize).
func layout(viewport_size: Vector2) -> void:
	_viewport_size = viewport_size
	_px_per_m = ViewMath.px_per_m(viewport_size.x, camera_width_m)
	position = ViewMath.cinder_center(viewport_size)
	var rect: Rect2 = ViewMath.battle_rect(viewport_size)
	rect.position -= position
	var arena_m: float = 52.0
	if _world != null:
		arena_m = _world.config.tuning.arena_radius
	_background.setup(_px_per_m, arena_m, rect)
	_cinder.radius_px = cinder_radius_px()
	_fx.emitter.cinder_radius_px = cinder_radius_px()
	if _world != null:
		_setup_enemy_renderer()


## Events lost by this view's cursors (aim + beams) since start; 0 unless the view fell behind the ring.
func events_lost_total() -> int:
	return _events.lost_total + _beams.events_lost_total()


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
	var band: int = displayed_band(cinder.band, band_override)
	var clock_s: float = (float(_world.tick) + alpha) * SimWorld.DT
	_cinder.heart_clock_s = clock_s
	_cinder.set_state(hp_frac, band, _aim, now_s)
	_background.set_optic_range(_world.stats.optic_range)
	_background.apply_state(clock_s, band, _world.enemies.alive_count)
	_enemies.render(_world, alpha)
	_beams.update(_world, now_s, _px_per_m, _cinder.emitter_position(), _enemies)
	_fx.update(_world, alpha, _game_visual(), band)


## The particle effect spawner (V1-12 impacts/muzzle through `fx().emitter`, V1-14 big-event counters).
func fx() -> FxSpawner:
	return _fx


func _setup_particles(settings: VisualSettings) -> void:
	_particles = ParticleRenderer.new()
	_particles.name = "Particles"
	add_child(_particles)
	_particles.setup(settings.quality.particle_cap if settings != null else 400)
	_fx.setup(_particles, _enemies)
	_fx.emitter.cinder_radius_px = cinder_radius_px()
	if settings != null:
		settings.quality_changed.connect(_on_quality_changed)


@warning_ignore("unused_parameter")
func _on_quality_changed(tier: int) -> void:  # gdlint: ignore=unused-argument
	var settings: VisualSettings = _game_visual()
	if settings != null:
		_particles.setup(settings.quality.particle_cap)
		_fx.setup(_particles, _enemies)
		_fx.emitter.cinder_radius_px = cinder_radius_px()


## Exposed for the debug overlay (M1-24) to override the displayed band.
func cinder_view() -> CinderView:
	return _cinder


func px_per_m() -> float:
	return _px_per_m


func _update_aim() -> void:
	var store: EnemyStore = _world.enemies
	while _events.poll(_world.events) > 0:
		for i: int in _events.count:
			var kind: int = _events.kind_at(i)
			if kind == SimEventKind.CINDER_HIT:
				_cinder.notify_hit()
			if kind != SimEventKind.SHOT_FIRED:
				continue
			_cinder.notify_shot()
			var idx: int = _events.a_at(i)
			if idx >= 0 and idx < store.high_water:
				_aim = atan2(store.pos_y[idx], store.pos_x[idx])


func _setup_enemy_renderer() -> void:
	var defs: Array[EnemyDef] = _world.config.enemies
	var radii := PackedFloat32Array()
	for def: EnemyDef in defs:
		radii.append(def.radius)
	_enemies.visual = _game_visual()
	_enemies.setup(_px_per_m, radii, EnemyStore.DEFAULT_CAPACITY, ProjectileStore.DEFAULT_CAPACITY, _cinder_radius_m())
	var local: Rect2 = ViewMath.battle_rect(_viewport_size)
	local.position -= ViewMath.cinder_center(_viewport_size)
	_enemies.set_cull(EnemyRenderer.cull_rect_for(local, _px_per_m))


func _cinder_radius_m() -> float:
	if _world != null:
		return _world.config.tuning.cinder_radius
	return 2.0


func _on_viewport_resized() -> void:
	layout(get_viewport_rect().size)


## Switches the camera width (32 m default, 38 m for comparison) and relayouts.
func set_camera_width_m(width_m: float) -> void:
	camera_width_m = width_m
	layout(_viewport_size)


## Outer radius of Cinder's emitter ring in px: the armor ring (0.92 of it) is Cinder's hit radius
## times VISUAL_SCALE (about 100 px at 1080 width and 32 m), art bible 4.1.
func cinder_radius_px() -> float:
	return _cinder_radius_m() * _px_per_m * ViewMath.VISUAL_SCALE / 0.92


## The `Game` autoload's visual settings, looked up by path so capture tools without autoloads still load.
func _game_visual() -> VisualSettings:
	var game: Node = get_node_or_null("/root/Game")
	if game == null:
		return null
	var v: Variant = game.get("visual")
	if v is VisualSettings:
		var settings: VisualSettings = v
		return settings
	return null


## View-only band override for the Cinder rig, the arena haze and the FX (debug overlay); the sim band when < 0.
static func displayed_band(sim_band: int, override: int) -> int:
	return sim_band if override < 0 else clampi(override, 0, 3)
