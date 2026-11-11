class_name RunTally
extends RefCounted
## Event counters of ONE run for the Service Record (lifetime stats). Reads the sim's own event stream (`world.events`,
## `SimEventKind`) through a private `EventCursor`; never writes the sim. `RunController` hands it to the `TickDriver`
## (polled after every tick, so the 1024-event ring can never overflow) and polls it again before a checkpoint and at
## the end of the run. What only the event stream knows: shots, crits, highest hit, hull damage taken and the scrap
## spent on upgrades. Everything else is read from the finished world (`RunTotals`).
## Resume: the tally is saved inside the run checkpoint (`to_dict`, taken at the same instant as the snapshot) and
## restored with it (`from_dict`), so a resumed run neither loses nor double counts a single event. A snapshot without a
## tally (written by an older build) restores a `partial` tally: its event totals are then not committed.

const INT32_MAX: int = 2147483647

var shots: int = 0
var crits: int = 0
## Highest single laser hit; a hit that overflowed the event field (int32) counts as `INT32_MAX`.
var hit_max: int = 0
## Sum of the hull damage of every enemy hit on Cinder (each hit as the event reports it, rounded to whole points).
var hull: int = 0
## Run upgrade levels bought.
var levels: int = 0
## Scrap spent on run upgrades (the sim's own cost formula, summed per purchase).
var spent: BigNum = BigNum.zero()
## True when events before the restore point are unknown (an old snapshot without a tally).
var partial: bool = false
## Events that fell out of the ring before they were read (should stay 0).
var lost: int = 0

var _events: EventCursor = EventCursor.new()
var _defs: Array[RunUpgradeDef] = []
var _levels: PackedInt32Array = PackedInt32Array()


## Binds to a world. `resumed` skips whatever the restored world already holds in its ring (a restore starts empty,
## and the tally state comes from the snapshot).
func bind(world: SimWorld, resumed: bool = false) -> void:
	_defs = world.config.upgrades
	_levels = world.run_levels.duplicate()
	if resumed:
		_events.sync_to(world.events)
	else:
		_events.cursor = 0


## Reads every unseen event. Cheap and allocation free; call after each tick.
func poll(world: SimWorld) -> void:
	while _events.poll(world.events) > 0:
		for i: int in _events.count:
			_apply(_events.kind_at(i), _events.a_at(i), _events.b_at(i))
	lost = _events.lost_total


func to_dict() -> Dictionary:
	return {
		"shots": shots,
		"crits": crits,
		"hit_max": hit_max,
		"hull": hull,
		"levels": levels,
		"spent": spent.to_text(),
		"lost": lost,
	}


## Restores the counters of a checkpoint and binds to the restored `world`. An empty or damaged `state` gives a
## `partial` tally.
static func from_dict(state: Dictionary, world: SimWorld) -> RunTally:
	var t: RunTally = RunTally.new()
	t.bind(world, true)
	var ok: bool = true
	for key: String in ["shots", "crits", "hit_max", "hull", "levels", "spent"]:
		ok = ok and state.has(key)
	if not ok:
		t.partial = true
		return t
	t.shots = _int(state, "shots")
	t.crits = _int(state, "crits")
	t.hit_max = _int(state, "hit_max")
	t.hull = _int(state, "hull")
	t.levels = _int(state, "levels")
	t.lost = _int(state, "lost")
	var raw: Variant = state["spent"]
	var text: String = raw if raw is String else ""
	var before: int = BigNum.error_count
	t.spent = BigNum.parse(text)
	if text.is_empty() or BigNum.error_count != before:
		t.spent = BigNum.zero()
		t.partial = true
	return t


## True when every event of the run was seen.
func exact() -> bool:
	return not partial and lost == 0


func _apply(kind: int, a: int, b: int) -> void:
	match kind:
		SimEventKind.SHOT_FIRED:
			shots += 1
			if b == 1:
				crits += 1
		SimEventKind.ENEMY_HIT:
			hit_max = maxi(hit_max, b if b > 0 else INT32_MAX)
		SimEventKind.CINDER_HIT:
			hull += maxi(a, 0)
		SimEventKind.UPGRADE_BOUGHT:
			_buy(a, b)


## Scrap cost of levels `old .. new_level - 1` of row `index`: the sim's own floats summed in its order.
func _buy(index: int, new_level: int) -> void:
	if index < 0 or index >= _levels.size() or index >= _defs.size():
		return
	var old: int = _levels[index]
	if new_level <= old:
		return
	var def: RunUpgradeDef = _defs[index]
	var total: float = 0.0
	for lv: int in range(old, new_level):
		total += Curves.upgrade_cost(def.c0, def.g, lv)
	spent = spent.add(BigNum.from_float(total))
	levels += new_level - old
	_levels[index] = new_level


static func _int(d: Dictionary, key: String) -> int:
	var v: Variant = d.get(key, 0)
	if v is int:
		var i: int = v
		return maxi(i, 0)
	if v is float:
		var f: float = v
		if not is_nan(f) and not is_inf(f):
			return maxi(int(f), 0)
	return 0
