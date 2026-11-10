class_name FxSpawner
extends RefCounted
## Event-driven particle effects (V1-13): reads ENEMY_HIT, ENEMY_KILLED, BOSS_SPAWNED, BAND_CHANGED, CINDER_HIT and
## RUN_ENDED through its own EventCursor and spends them through FxEmitter into the ParticleRenderer's pools.
## Pure observer of the sim. Time is SIM time ((tick + alpha) * DT), so pause freezes every particle and 2x/4x
## speed plays the effects faster. Work per frame is bounded by FxRecipes budgets; extra events are skipped.
## Big-event counters (`boss_kills`, `band_worse_count`, `cinder_hits`, `last_cinder_damage`) let V1-14
## (shake, slow-mo) react without a second cursor on the same events.
## Usage: `setup(renderer, enemy_renderer)`, then `update(world, alpha, visual, band)` every frame after the
## enemy renderer has rendered (draw_pos needs its stand-offs).

var emitter: FxEmitter
var hits_spawned: int = 0
var hits_dropped: int = 0
## VT-4 counters: deflection effects fired, motes spawned (tests and the perf report read them).
var deflects_spawned: int = 0
var motes_spawned: int = 0
var kills_spawned: int = 0
var kills_dropped: int = 0
var boss_kills: int = 0
var band_worse_count: int = 0
var cinder_hits: int = 0
var last_cinder_damage: int = 0
## CPU time of the latest update() call in microseconds (event handling, spawning, ring upload).
var last_update_usec: int = 0
## Game speed (set by the host): 4x and 8x cut the hit and kill budgets and the sparks per hit (`SpeedLoad`).
var play_speed: int = 1
## Test hook: sizes of the per-slot arrays; update() must never change it.
var resize_count: int = 0

var _renderer: ParticleRenderer
var _enemies: EnemyRenderer
var _events := EventCursor.new()
var _hit_until := PackedFloat32Array()
var _world_id: int = 0
var _last_t: float = 0.0
var _ember_acc: float = 0.0
var _hit_budget: int = 0
var _kill_budget: int = 0
var _cinder_budget: int = 0
var _written_start: int = 0
var _particle_budget: int = 0
var _quality_fallback: VisualQuality = VisualQuality.high()
var _rng := RandomNumberGenerator.new()
# VT-4 (docs/design/12): tier looks read from the plating_pct and nano_repair run levels, refreshed only on a change
var _tiers: VisualTierModel = null
var _plating_row: int = -1
var _nano_row: int = -1
var _plating_level: int = -1
var _nano_level: int = -1
var _deflect_scale: float = 0.0
var _mote_base: int = 0
var _mote_speed: float = 0.0
var _mote_size: float = 0.0
var _mote_acc: float = 0.0


func setup(renderer: ParticleRenderer, enemies: EnemyRenderer) -> void:
	_renderer = renderer
	_enemies = enemies
	emitter = FxEmitter.new(renderer.additive, renderer.smoke)
	_rng.seed = 77
	_tiers = VisualTierModel.shared()
	_world_id = 0


## Spawns this frame's effects. `band` is the displayed exposure band (drives the embers); `visual` may be null.
func update(world: SimWorld, alpha: float, visual: VisualSettings, band: int) -> void:
	var t0: int = Time.get_ticks_usec()
	var a: float = clampf(alpha, 0.0, 1.0)
	var sim_t: float = (float(world.tick) + a) * SimWorld.DT
	var wid: int = world.get_instance_id()
	if wid != _world_id or sim_t < _last_t - 0.5:
		_reset(world, wid)
	var dt: float = maxf(sim_t - _last_t, 0.0)
	_last_t = sim_t
	var quality: VisualQuality = _quality_fallback
	var reduce: bool = false
	if visual != null:
		reduce = visual.reduce_motion
		if visual.quality != null:
			quality = visual.quality
	_apply_quality(quality, reduce)
	_renderer.set_time(sim_t)
	emitter.now = sim_t
	_hit_budget = SpeedLoad.scaled(FxRecipes.hit_budget(quality.tier), play_speed)
	_kill_budget = SpeedLoad.scaled(FxRecipes.kill_budget(quality.tier), play_speed)
	_cinder_budget = FxRecipes.CINDER_HIT_BUDGET
	_particle_budget = FxRecipes.particle_budget(quality.tier)
	_written_start = _written()
	_refresh_tiers(world)
	var store: EnemyStore = world.enemies
	while _events.poll(world.events) > 0:
		for i: int in _events.count:
			_on_event(_events.kind_at(i), _events.a_at(i), _events.b_at(i), store, a, sim_t)
	_embers(band, dt)
	_motes(world, dt, quality.tier, reduce, visual != null and visual.high_contrast)
	_renderer.flush()
	last_update_usec = Time.get_ticks_usec() - t0


func events_lost_total() -> int:
	return _events.lost_total


func _on_event(kind: int, a: int, b: int, store: EnemyStore, alpha: float, sim_t: float) -> void:
	match kind:
		SimEventKind.ENEMY_HIT:
			_on_hit(a, store, alpha, sim_t)
		SimEventKind.ENEMY_KILLED:
			_on_kill(a, b, store, alpha)
		SimEventKind.BOSS_SPAWNED:
			if a >= 0 and a < store.high_water:
				emitter.warning_ring(_enemies.draw_pos(store, a, alpha))
		SimEventKind.BAND_CHANGED:
			if b > a:
				band_worse_count += 1
				emitter.band_worse(b)
			else:
				emitter.band_better()
		SimEventKind.CINDER_HIT:
			cinder_hits += 1
			last_cinder_damage = a
			if _cinder_budget > 0:
				_cinder_budget -= 1
				emitter.cinder_hit(FxRecipes.accent(b))
				if _deflect_scale > 0.0:
					deflects_spawned += 1
					@warning_ignore("return_value_discarded")
					emitter.deflect(emitter.last_hit_angle, _deflect_scale)
		SimEventKind.RUN_ENDED:
			emitter.cinder_death()


func _on_hit(idx: int, store: EnemyStore, alpha: float, sim_t: float) -> void:
	if idx < 0 or idx >= store.high_water or idx >= _hit_until.size():
		return
	if _hit_budget <= 0 or _over_budget() or sim_t < _hit_until[idx]:
		hits_dropped += 1
		return
	_hit_budget -= 1
	_hit_until[idx] = sim_t + FxRecipes.HIT_COOLDOWN_S
	hits_spawned += 1
	var pos: Vector2 = _enemies.draw_pos(store, idx, alpha)
	var radius: float = _enemies.sprite_radius_px(store.type_id[idx])
	# the beam ends on the near hull edge: pull the impact toward Cinder by 0.6 of the sprite radius
	var toward: Vector2 = -pos.normalized() if pos.length_squared() > 1.0 else Vector2.UP
	emitter.impact(pos + toward * radius * 0.6, toward, store.alive_count)


func _on_kill(idx: int, type_index: int, store: EnemyStore, alpha: float) -> void:
	if idx < 0 or idx >= store.high_water:
		return
	var is_boss: bool = type_index == FxRecipes.BOSS_TYPE
	if (_kill_budget <= 0 or _over_budget()) and not is_boss:
		kills_dropped += 1
		return
	_kill_budget -= 1
	kills_spawned += 1
	if is_boss:
		boss_kills += 1
	var pos: Vector2 = _enemies.draw_pos(store, idx, alpha)
	emitter.kill(type_index, pos, _enemies.sprite_radius_px(type_index), store.alive_count)


func _written() -> int:
	return _renderer.additive.total_written + _renderer.smoke.total_written


## True once this frame already wrote its particle budget (extra hits and kills are skipped, not queued).
func _over_budget() -> bool:
	return _written() - _written_start >= _particle_budget


func _embers(band: int, dt: float) -> void:
	var rate: float = FxRecipes.ember_rate(band)
	if rate <= 0.0:
		_ember_acc = 0.0
		return
	_ember_acc += rate * dt
	var n: int = mini(floori(_ember_acc), FxRecipes.MAX_EMBERS_PER_FRAME)
	_ember_acc = minf(_ember_acc - float(floori(_ember_acc)), 1.0)
	for k: int in n:
		emitter.ember(_rng.randf() * TAU)


func _apply_quality(quality: VisualQuality, reduce: bool) -> void:
	emitter.sparks_per_hit = SpeedLoad.scaled(quality.sparks_per_hit, play_speed)
	emitter.rings_enabled = quality.impact_rings
	emitter.reduce_motion = reduce
	emitter.quality_tier = int(quality.tier)


func _reset(world: SimWorld, wid: int) -> void:
	_world_id = wid
	_events.sync_to(world.events)
	var cap: int = world.enemies.capacity
	if _hit_until.size() != cap:
		if _hit_until.resize(cap) != OK:
			push_error("FxSpawner: resize failed")
		resize_count += 1
	_hit_until.fill(0.0)
	_ember_acc = 0.0
	_last_t = (float(world.tick)) * SimWorld.DT
	_mote_acc = 0.0
	_plating_row = _row_of(world, "plating_pct")
	_nano_row = _row_of(world, "nano_repair")
	_plating_level = -1
	_nano_level = -1
	_renderer.clear()


func _row_of(world: SimWorld, upgrade_id: String) -> int:
	var ups: Array[RunUpgradeDef] = world.config.upgrades
	for i: int in ups.size():
		if ups[i].id == upgrade_id:
			return i
	return -1


## Re-reads the PLATED and MK looks, only when the run level of that row changed (a tier is a pure function of it).
func _refresh_tiers(world: SimWorld) -> void:
	var pl: int = world.run_levels[_plating_row] if _plating_row >= 0 else 0
	if pl != _plating_level:
		_plating_level = pl
		var def: VisualTierDef = _tiers.def_for("plating_pct", pl)
		var deflect: bool = def != null and def.param("deflect") >= 2.0
		_deflect_scale = def.param("spark_scale", 1.0) if deflect else 0.0
	var nl: int = world.run_levels[_nano_row] if _nano_row >= 0 else 0
	if nl != _nano_level:
		_nano_level = nl
		var nd: VisualTierDef = _tiers.def_for("nano_repair", nl)
		_mote_base = roundi(nd.param("motes")) if nd != null else 0
		_mote_speed = nd.param("speed") if nd != null else 0.0
		_mote_size = nd.param("size") if nd != null else 0.0


## Repair motes (VT-4): count / 1.3 s spawns per second, 40% at full integrity and 100% while hurt. Off on LOW and
## under high contrast; MID 60% count without halo; reduce motion half count and no drift. Skipped when this frame
## already wrote its particle budget, so a crowded frame is never made worse.
func _motes(world: SimWorld, dt: float, tier: int, reduce: bool, high_contrast: bool) -> void:
	var count: int = 0 if high_contrast else FxRecipes.mote_count(_mote_base, tier, reduce)
	if count <= 0:
		_mote_acc = 0.0
		return
	var cinder: CinderState = world.cinder
	var hurt: bool = cinder != null and cinder.hp < cinder.max_hp
	_mote_acc += FxRecipes.mote_rate(count, hurt) * dt
	var n: int = mini(floori(_mote_acc), FxRecipes.MAX_MOTES_PER_FRAME)
	_mote_acc = minf(_mote_acc - float(floori(_mote_acc)), 1.0)
	if _over_budget():
		return
	var speed: float = 0.0 if reduce else _mote_speed
	for k: int in n:
		@warning_ignore("return_value_discarded")
		emitter.mote(_rng.randf() * TAU, speed, _mote_size, tier == 0)
		motes_spawned += 1
