class_name BattleView
extends Node2D
## Battlefield assembly (TECH_ARCHITECTURE 1.4): arena backdrop, enemies/bolts, beams and
## Cinder, all placed at Cinder's screen position (center of the top 56% of the viewport).
## Pure observer: reads the SimWorld in render(), never writes it. The HUD and the bottom
## panel live in `Hud`, not here.
## Usage: add to the scene, `bind(world)` after creating a run, `render(alpha)` every frame.
## Cinder's aim angle follows the target of the latest SHOT_FIRED event (own EventCursor);
## it keeps the last angle between shots (initially straight up).

## A tier-up banner starts (VT-5); the host owns the banner control (`TierBanner`) and plays the moment.
signal tier_banner_requested(moment: TierUpMoment)

## View-only override of the displayed exposure band (debug overlay, M1-24); -1 shows the sim's band.
var band_override: int = -1
## Camera width in meters. With `auto_fit` (default, V1-23) it follows Cinder's optic range: ViewMath.fit_width_m,
## eased by CameraFit. `set_camera_width_m` switches auto-fit off and pins a manual width (32 / 38 m comparisons).
var camera_width_m: float = ViewMath.BASE_FIT_WIDTH_M
var auto_fit: bool = true
var _world: SimWorld
var _zoom := CameraFit.new()
var _px_per_m: float = ViewMath.px_per_m(1080.0, ViewMath.BASE_FIT_WIDTH_M)
var _sprite_ppm: float = ViewMath.sprite_ppm(1080.0, ViewMath.BASE_FIT_WIDTH_M)
var _sprite_factor: float = ViewMath.SPRITE_BASE_FACTOR
var _battle_local := Rect2()
## Unobstructed field edges in viewport px (HUD bottom, panel height, side panel); negative top/bottom = fallback.
var _inset_tb := Vector2(-1.0, -1.0)
var _inset_lr := Vector2.ZERO
var _viewport_size := Vector2(1080.0, 1920.0)
var _aim: float = -PI * 0.5
var _events := EventCursor.new()
var _particles: ParticleRenderer
var _fx := FxSpawner.new()
var _impact := ImpactDriver.new()
var _tier_up := TierUpDirector.new()
var _tier_flash := TierUpFlash.new()
## Game speed (1-4) the host reports for the slow-mo rule (no slow-mo above 2x).
var _speed_hint: int = 1
var _base_position := Vector2.ZERO

@onready var _background: ArenaBackground = $Background
@onready var _enemies: EnemyRenderer = $Enemies
@onready var _beams: BeamRenderer = $Beams
@onready var _cinder: CinderView = $Cinder
@onready var _numbers: DamageNumberLayer = $DamageNumbers


func _ready() -> void:
	get_viewport().size_changed.connect(_on_viewport_resized)
	# Looked up by path: scripts that compile this class without autoloads (capture tools) must still load.
	var settings: VisualSettings = _game_visual()
	_cinder.visual = settings
	_beams.visual = settings
	_numbers.visual = settings
	if settings != null:
		_background.setup_visual(settings)
	_setup_particles(settings)
	add_child(_tier_flash)  # VT-5: Cinder's tier-up flash, above the particles
	move_child(_numbers, -1)  # numbers read on top of the particles
	layout(get_viewport_rect().size)


## Recomputes scale and positions for a viewport size (also called on resize).
func layout(viewport_size: Vector2) -> void:
	_viewport_size = viewport_size
	var field: Rect2 = field_rect()
	_base_position = field.get_center()
	position = _base_position
	var rect: Rect2 = ViewMath.battle_rect(viewport_size)
	rect.size.y = field.end.y
	rect.position -= position
	_battle_local = rect
	if auto_fit and _world != null:
		camera_width_m = _fit_target()
		_zoom.snap(camera_width_m)
	_update_scales()
	_background.setup(_px_per_m, _arena_radius_m(), rect, _sprite_ppm)
	_apply_scale_to_children()
	if _world != null:
		_setup_enemy_renderer()


## Vertical open field (V1-23): `top_px` = HUD bottom edge, `bottom_px` = panel height, in viewport px; negative =
## fallback (top 0, bottom 56 percent). Keeps the horizontal insets (`set_field_rect`).
func set_field_insets(top_px: float, bottom_px: float) -> void:
	_inset_tb = Vector2(top_px, bottom_px)
	layout(_viewport_size)


## V1-28: the open field as a rect in viewport px (wide layout: left of the side panel), stored as insets.
func set_field_rect(rect: Rect2) -> void:
	_inset_lr = Vector2(maxf(rect.position.x, 0.0), maxf(_viewport_size.x - rect.end.x, 0.0))
	set_field_insets(rect.position.y, _viewport_size.y - rect.end.y)


## The unobstructed field in viewport px.
func field_rect() -> Rect2:
	return ViewMath.field_rect(_viewport_size, _inset_tb.x, _inset_tb.y, _inset_lr.x, _inset_lr.y)


## Events lost by this view's cursors (aim + beams) since start; 0 unless the view fell behind the ring.
func events_lost_total() -> int:
	return _events.lost_total + _beams.events_lost_total() + _numbers.events_lost_total()


## Starts observing `world` (skips events already pushed).
func bind(world: SimWorld) -> void:
	_world = world
	_cinder.set_frame(world.config.frame_id)
	_cinder.bind_world(world)
	_events.sync_to(world.events)
	_beams.bind(world)
	_tier_up.bind(world)
	_numbers.bind(world)
	_impact.bind(world)
	apply_shake(Vector2.ZERO)
	_aim = -PI * 0.5
	_zoom = CameraFit.new()
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
	_update_zoom(now_s)
	var band: int = displayed_band(cinder.band, band_override)
	var clock_s: float = (float(_world.tick) + alpha) * SimWorld.DT
	_cinder.heart_clock_s = clock_s
	_cinder.set_state(hp_frac, band, _aim, now_s)
	_background.set_optic_range(_world.stats.optic_range)
	_background.apply_state(clock_s, band, _world.enemies.alive_count)
	_enemies.render(_world, alpha)
	_beams.update(_world, now_s, _px_per_m, _cinder.emitter_position(), _enemies)
	_fx.update(_world, alpha, _game_visual(), band)
	_numbers.update(_enemies, now_s, alpha)
	apply_shake(_impact.update(_world, now_s, _game_visual(), _speed_hint, _viewport_size.x / 1080.0))
	_update_tier_up(now_s)


## Adopts the current upgrade levels without a tier-up moment (debug fast-forward, hidden frames).
func skip_tier_ups() -> void:
	if _world != null:
		_tier_up.sync(_world)


## VT-5: polls the upgrade levels, starts Cinder's flash and asks the host for the banner.
func _update_tier_up(now_s: float) -> void:
	var settings: VisualSettings = _game_visual()
	var reduce: bool = settings != null and settings.reduce_motion
	var tier: int = settings.quality.tier if settings != null else VisualQuality.Tier.HIGH
	_tier_up.update(_world, now_s, reduce or tier == VisualQuality.Tier.LOW)
	var flash: TierUpMoment = _tier_up.take_flash()
	if flash != null:
		_tier_flash.radius_px = cinder_radius_px()
		_tier_flash.start(now_s, TierUpFlash.mode_for(tier, reduce))
	_tier_flash.update(now_s)
	var banner: TierUpMoment = _tier_up.take_banner()
	if banner != null:
		tier_banner_requested.emit(banner)


## Moves the battlefield root by `offset` px from its layout position (screen shake). The HUD is a separate
## scene and never moves.
func apply_shake(offset: Vector2) -> void:
	position = _base_position + offset


## Slow-mo factor for the host to multiply into the run controller's frame delta (view-only pacing).
func time_scale() -> float:
	return _impact.time_scale


func set_speed_hint(speed: int) -> void:
	_speed_hint = speed


func impact() -> ImpactDriver:
	return _impact


## The particle effect spawner (V1-12 impacts/muzzle through `fx().emitter`, V1-14 big-event counters).
func fx() -> FxSpawner:
	return _fx


func _setup_particles(settings: VisualSettings) -> void:
	_particles = ParticleRenderer.new()
	_particles.name = "Particles"
	add_child(_particles)
	_particles.setup(settings.quality.particle_cap if settings != null else 400)
	_fx.setup(_particles, _enemies)
	_apply_scale_to_children()
	if settings != null:
		settings.quality_changed.connect(_on_quality_changed)


@warning_ignore("unused_parameter")
func _on_quality_changed(tier: int) -> void:  # gdlint: ignore=unused-argument
	var settings: VisualSettings = _game_visual()
	if settings != null:
		_particles.setup(settings.quality.particle_cap)
		_fx.setup(_particles, _enemies)
		_apply_scale_to_children()


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
	_enemies.setup(
		_px_per_m, radii, EnemyStore.DEFAULT_CAPACITY, ProjectileStore.DEFAULT_CAPACITY, _cinder_radius_m(), _sprite_ppm
	)
	_set_cull()


func _set_cull() -> void:
	_enemies.set_cull(EnemyRenderer.cull_rect_for(_battle_local, _px_per_m, _enemies.max_sprite_radius_px() * 1.15))


func _arena_radius_m() -> float:
	if _world != null:
		return _world.config.tuning.arena_radius
	return 52.0


func _fit_target() -> float:
	return ViewMath.fit_width_m(_world.stats.optic_range, _arena_radius_m(), _viewport_size, field_rect().size)


## Eases the camera toward the auto-fit width and re-scales the view when it moved (a purchase of Optic Range).
func _update_zoom(now_s: float) -> void:
	if not auto_fit:
		return
	var reduce: bool = false
	var settings: VisualSettings = _game_visual()
	if settings != null:
		reduce = settings.reduce_motion
	var w: float = _zoom.step(_fit_target(), now_s, reduce)
	if w == camera_width_m:
		return
	camera_width_m = w
	_update_scales()
	_background.set_camera(_px_per_m, _sprite_ppm)
	_apply_scale_to_children()
	_enemies.set_view_scale(_px_per_m, _sprite_ppm, _cinder_radius_m())
	_set_cull()


func _update_scales() -> void:
	_px_per_m = ViewMath.px_per_m(_viewport_size.x, camera_width_m)
	var fs: Vector2 = field_rect().size if auto_fit else Vector2.INF  # sprites follow the zoom, not the aspect
	var cam: float = ViewMath.sprite_cam_m(camera_width_m, _viewport_size.x, fs)
	_sprite_ppm = ViewMath.sprite_ppm(_viewport_size.x, cam)
	_sprite_factor = ViewMath.sprite_factor(cam)


## Pushes the sprite-sized values to Cinder, the beams and the particle emitter.
func _apply_scale_to_children() -> void:
	_cinder.radius_px = cinder_radius_px()
	_beams.px_scale = _sprite_factor
	_fx.emitter.cinder_radius_px = cinder_radius_px()
	_fx.emitter.fx_scale = _sprite_factor
	_numbers.text_scale = _viewport_size.x / 1080.0
	_numbers.cinder_radius_px = cinder_radius_px()


func _cinder_radius_m() -> float:
	if _world != null:
		return _world.config.tuning.cinder_radius
	return 2.0


func _on_viewport_resized() -> void:
	layout(get_viewport_rect().size)


## Pins a manual camera width (comparisons, captures): switches auto-fit off and relayouts.
func set_camera_width_m(width_m: float) -> void:
	auto_fit = false
	camera_width_m = width_m
	layout(_viewport_size)


## Current eased auto-fit camera width in meters.
func camera_m() -> float:
	return camera_width_m


## Sprite size factor (relative to pre-V1-23 pixels) of the current camera.
func sprite_factor() -> float:
	return _sprite_factor


func sprite_ppm() -> float:
	return _sprite_ppm


## Outer radius of Cinder's emitter ring in px: the armor ring (0.92 of it) is Cinder's hit radius
## times VISUAL_SCALE at the sprite scale and CINDER_SCALE 0.75 (about 65 px at 1080 width and the base zoom).
func cinder_radius_px() -> float:
	return _cinder_radius_m() * _sprite_ppm * ViewMath.VISUAL_SCALE * ViewMath.CINDER_SCALE / 0.92


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
