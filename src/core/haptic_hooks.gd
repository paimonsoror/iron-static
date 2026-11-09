class_name HapticHooks
extends RefCounted
## Sim events -> haptics (M4-22), the haptic twin of `AudioEventRouter`: reads `world.events` through its own
## EventCursor, never writes sim state. Mapping (07 s4): UPGRADE_BOUGHT -> buy tick; BOSS_SPAWNED -> medium pulse;
## RUN_ENDED -> long pulse. Everything else is silent (micro-events off). The draft pick has no sim event yet:
## call `draft_pick()` from the draft overlay when it exists (M4-16).

var _haptics: Haptics = null
var _world: SimWorld = null
var _events: EventCursor = EventCursor.new()


func _init(haptics: Haptics = null) -> void:
	_haptics = haptics


## Starts observing `world` (events already pushed are skipped).
func bind(world: SimWorld) -> void:
	_world = world
	_events.sync_to(world.events)


## Fast-forward or hidden frames: drop pending events without buzzing.
func skip() -> void:
	if _world != null:
		_events.sync_to(_world.events)


## Drains new events into pulses. Call once per rendered frame.
func update() -> void:
	if _world == null or _haptics == null:
		return
	while _events.poll(_world.events) > 0:
		for i: int in _events.count:
			route(_events.kind_at(i))


func route(kind: int) -> void:
	match kind:
		SimEventKind.UPGRADE_BOUGHT:
			_haptics.buy()
		SimEventKind.BOSS_SPAWNED:
			_haptics.boss_spawn()
		SimEventKind.RUN_ENDED:
			_haptics.death()


## Hook for the wave-10 draft overlay (no sim event: the pick is a UI action).
func draft_pick() -> void:
	if _haptics != null:
		_haptics.draft_pick()
