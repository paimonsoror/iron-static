class_name FtueWatcher
extends RefCounted
## Turns sim events and the world state into FTUE events (M4-26): ENEMY_KILLED -> first_kill, a dart spawn ->
## dart_first_seen, CINDER_HIT -> first_damage_taken, DRAFT_OPENED -> draft_open_first, RUN_ENDED -> death_first,
## cycle_rate affordable after a kill -> scrap_affords_cycle_rate, and UPGRADE_BOUGHT -> `row_bought`. Reads
## `world.events` through its own cursor and never writes the sim. Each trigger is sent once per bound world.

const CHECK_EVERY: int = 10

var _world: SimWorld = null
var _events: EventCursor = EventCursor.new()
var _fired: Dictionary = {}
var _dart_type: int = -1
var _rate_index: int = -1
var _frame: int = 0


## Starts watching `world` (events already pushed are skipped).
func bind(world: SimWorld) -> void:
	_world = world
	_events.sync_to(world.events)
	_fired.clear()
	_frame = 0
	_dart_type = -1
	_rate_index = -1
	for i: int in world.config.enemies.size():
		if world.config.enemies[i].id == "dart":
			_dart_type = i
	for i: int in world.config.upgrades.size():
		if world.config.upgrades[i].id == "cycle_rate":
			_rate_index = i


func has_fired(trigger: String) -> bool:
	return _fired.has(trigger)


## Drains new events and checks the scrap condition. Call once per rendered frame.
func update(state: FtueState) -> void:
	if _world == null or state == null:
		return
	while _events.poll(_world.events) > 0:
		for i: int in _events.count:
			_route(state, _events.kind_at(i), _events.a_at(i), _events.b_at(i))
	_frame += 1
	if _frame % CHECK_EVERY == 0:
		_check_affordable(state)


func _route(state: FtueState, kind: int, a: int, b: int) -> void:
	match kind:
		SimEventKind.ENEMY_KILLED:
			_fire(state, FtueScript.FIRST_KILL)
		SimEventKind.ENEMY_SPAWNED:
			if b == _dart_type and _dart_type >= 0:
				_fire(state, FtueScript.DART_FIRST_SEEN)
		SimEventKind.CINDER_HIT:
			_fire(state, FtueScript.FIRST_DAMAGE_TAKEN)
		SimEventKind.DRAFT_OPENED:
			_fire(state, FtueScript.DRAFT_OPEN_FIRST)
		SimEventKind.RUN_ENDED:
			_fire(state, FtueScript.DEATH_FIRST)
		SimEventKind.UPGRADE_BOUGHT:
			var ups: Array[RunUpgradeDef] = _world.config.upgrades
			if a >= 0 and a < ups.size():
				@warning_ignore("return_value_discarded")
				state.row_bought(ups[a].id)


func _check_affordable(state: FtueState) -> void:
	if _fired.has(FtueScript.SCRAP_AFFORDS_CYCLE_RATE) or not _fired.has(FtueScript.FIRST_KILL) or _rate_index < 0:
		return
	if UpgradeSystem.preview(_world, _rate_index, 1).affordable:
		_fire(state, FtueScript.SCRAP_AFFORDS_CYCLE_RATE)


func _fire(state: FtueState, trigger: String) -> void:
	if _fired.has(trigger):
		return
	_fired[trigger] = true
	@warning_ignore("return_value_discarded")
	state.on_event(trigger)
