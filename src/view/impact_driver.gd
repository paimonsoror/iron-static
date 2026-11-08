class_name ImpactDriver
extends RefCounted
## View-side reaction to big sim events (V1-14): feeds `ShakeModel` and `SlowmoModel` from its own EventCursor.
## Pure observer of the world; never writes it. `update` returns the shake offset in px for the BattleView root;
## `time_scale` is the slow-mo factor the host multiplies into the RunController's frame delta (wall time only).
## No allocation per frame (Vector2 is a value type). Cinder death shakes but has no slow-mo effect: the sim
## stops on that very tick, so there is nothing left to slow (impl, dropped for that moment).

var shake := ShakeModel.new()
var slowmo := SlowmoModel.new()
## Slow-mo factor for the next frame (1.0 = normal).
var time_scale: float = 1.0

var _events := EventCursor.new()
var _last_s: float = -1.0
var _world_id: int = 0


## Starts observing `world` (skips events already pushed) and clears shake and slow-mo.
func bind(world: SimWorld) -> void:
	_events.sync_to(world.events)
	_world_id = world.get_instance_id()
	shake.reset()
	slowmo.reset()
	time_scale = 1.0
	_last_s = -1.0


## Polls events, decays trauma and returns the shake offset in px (0 when shake is off). `visual` may be null.
func update(world: SimWorld, now_s: float, visual: VisualSettings, speed: int, width_scale: float) -> Vector2:
	if world.get_instance_id() != _world_id:
		bind(world)
	var dt: float = 0.0 if _last_s < 0.0 else clampf(now_s - _last_s, 0.0, 0.1)
	_last_s = now_s
	var max_px: float = 0.0
	var reduce: bool = false
	if visual != null:
		max_px = visual.effective_shake_px() * width_scale
		reduce = visual.reduce_motion
	var max_hp: float = world.cinder.max_hp
	while _events.poll(world.events) > 0:
		for i: int in _events.count:
			var kind: int = _events.kind_at(i)
			if max_px > 0.0:
				shake.add_event(kind, _events.a_at(i), _events.b_at(i), max_hp)
			if kind == SimEventKind.ENEMY_KILLED and _events.b_at(i) == ShakeModel.BOSS_TYPE:
				slowmo.trigger(SlowmoModel.Kind.BOSS_DEATH)
	shake.decay(dt)
	time_scale = slowmo.step(dt, speed, reduce)
	return shake.offset(now_s, max_px)
