class_name HapticHooks
extends RefCounted
## Sim events -> haptics (M4-22), the haptic twin of `AudioEventRouter`: reads `world.events` through its own
## EventCursor, never writes sim state. Mapping (07 s4): UPGRADE_BOUGHT -> buy tick, or the tier pulse instead of
## it when the purchase reaches a new visual tier (VT-5); BOSS_SPAWNED -> medium pulse; RUN_ENDED -> long pulse.
## Everything else is silent (micro-events off). The draft pick has no sim event yet: call `draft_pick()` from the
## draft overlay when it exists (M4-16).

const BUY_PULSES_PER_FRAME: int = 4

## Game speed (set by the host each frame): 4x and 8x cut the buy ticks per frame (`SpeedLoad`).
var speed: int = 1

var _haptics: Haptics = null
var _world: SimWorld = null
var _events: EventCursor = EventCursor.new()
var _tiers: TierRowTracker = TierRowTracker.new()
var _left: int = 1 << 30  # per-frame allowance; update() sets it (direct route() calls are unlimited)


func _init(haptics: Haptics = null) -> void:
	_haptics = haptics


## Starts observing `world` (events already pushed are skipped).
func bind(world: SimWorld) -> void:
	_world = world
	_events.sync_to(world.events)
	_tiers.bind(world)


## Fast-forward or hidden frames: drop pending events without buzzing.
func skip() -> void:
	if _world != null:
		_events.sync_to(_world.events)
		_tiers.sync(_world)


## Drains new events into pulses. Call once per rendered frame.
func update() -> void:
	if _world == null or _haptics == null:
		return
	_left = SpeedLoad.scaled(BUY_PULSES_PER_FRAME, speed)
	while _events.poll(_world.events) > 0:
		for i: int in _events.count:
			route(_events.kind_at(i), _events.a_at(i), _events.b_at(i))


## `a`/`b` are the event fields (UPGRADE_BOUGHT: row index, new level).
func route(kind: int, a: int = -1, b: int = 0) -> void:
	match kind:
		SimEventKind.UPGRADE_BOUGHT:
			var tier: int = _tiers.observe(a, b)
			if tier > 0:  # VT-5: the tier pulse replaces the buy tick of this purchase
				_haptics.tier_up(_tiers.is_top(a, tier))
			elif _left > 0:
				_left -= 1
				_haptics.buy()
		SimEventKind.BOSS_SPAWNED:
			_haptics.boss_spawn()
		SimEventKind.RUN_ENDED:
			_haptics.death()


## Hook for the draft overlay (no sim event: the pick is a UI action).
func draft_pick() -> void:
	if _haptics != null:
		_haptics.draft_pick()
