class_name FtueState
extends RefCounted
## Progress through the FTUE script (M4-25). Pure. Hints show only in runs 1 and 2 of a fresh profile: `run_no` is
## the number of the run being played (`runs_total + 1` at run start) and a state with `run_no > MAX_RUNS` or
## `skipped` shows nothing. At most one beat is `active` (drawn); events that fire while one is up queue their beats
## in CSV order. Silent beats complete at once. Every hint is skippable (`skip_all` ends every beat for good) and
## nothing here blocks play: `advance(dt)` only expires a beat after `DISPLAY_S`.
##
## Persistence: `to_dict` / `store_to` / `load_from` keep `{v, done, skipped}` under `KEY` in the profile `extra`
## dictionary (no schema bump, like `ModeUnlockFlag`). The active beat and the queue are runtime only.
##
## Public API:
##   static load_from(beat_list, profile) -> FtueState     (run_no = profile.runs_total + 1)
##   store_to(profile) -> void / dirty (bool: changed since the last store)
##   begin_run(runs_total) -> Array[FtueBeatDef]        (sets run_no, fires run1_start / run2_start)
##   on_event(trigger) -> Array[FtueBeatDef]            (beats it started or queued, silent ones already done)
##   complete(id) / row_bought(upgrade_id) / skip_all() / advance(dt)
##   active() / current_id() / is_done(id) / cold_open_due() / enabled()

const KEY: String = "ftue"
const VERSION: int = 1
## A drawn hint goes away on its own after this many seconds (the results FOUNDRY pulse stays until used).
const DISPLAY_S: float = 12.0

var beat_list: FtueScript = null
var run_no: int = 1
var skipped: bool = false
## True after a change that `store_to` has not written yet.
var dirty: bool = false

var _done: Dictionary = {}
var _active: FtueBeatDef = null
var _queue: Array[FtueBeatDef] = []
var _age_s: float = 0.0


func _init(new_script: FtueScript = null) -> void:
	beat_list = new_script if new_script != null else FtueScript.load_default()


## State of `profile`: a missing or damaged key is a fresh state (a profile with banked runs is then already past
## the cold open: `cold_open` counts as done once `runs_total > 0`).
static func load_from(new_script: FtueScript, profile: PlayerProfile) -> FtueState:
	var s: FtueState = FtueState.new(new_script)
	s.run_no = profile.runs_total + 1
	var raw: Variant = profile.extra.get(KEY, null)
	if raw is Dictionary:
		var d: Dictionary = raw
		s._read(d)
	if profile.runs_total > 0:
		s._done[FtueScript.COLD_OPEN] = true
	return s


func store_to(profile: PlayerProfile) -> void:
	profile.extra[KEY] = to_dict()
	dirty = false


func to_dict() -> Dictionary:
	var ids: Array = _done.keys()
	ids.sort()
	return {"v": VERSION, "done": ids, "skipped": skipped}


## Hints can still show: not skipped and within the first two runs.
func enabled() -> bool:
	return not skipped and run_no <= FtueScript.MAX_RUNS


## NEW GAME on a fresh profile shows the cold open once, before run 1.
func cold_open_due() -> bool:
	return enabled() and run_no == 1 and not is_done(FtueScript.COLD_OPEN)


func is_done(id: String) -> bool:
	return _done.has(id)


func active() -> FtueBeatDef:
	return _active


func queued_count() -> int:
	return _queue.size()


## Id of the beat on screen, else of the first beat still to come (a fresh state: `cold_open`); "" when none is left.
func current_id() -> String:
	if _active != null:
		return _active.id
	if not enabled():
		return ""
	for def: FtueBeatDef in beat_list.beats():
		if not _done.has(def.id) and def.max_runs >= run_no:
			return def.id
	return ""


## Starts run number `runs_total + 1`: resets the runtime beat and fires `run1_start` / `run2_start`.
func begin_run(runs_total: int) -> Array[FtueBeatDef]:
	run_no = runs_total + 1
	_active = null
	_queue.clear()
	_age_s = 0.0
	if run_no == 1:
		return on_event(FtueScript.RUN1_START)
	if run_no == 2:
		return on_event(FtueScript.RUN2_START)
	var none: Array[FtueBeatDef] = []
	return none


## An event happened. Returns the beats it started or queued (silent beats are already done). Beats that are done,
## above their `max_runs` or already waiting are ignored, so firing an event twice does nothing.
func on_event(trigger: String) -> Array[FtueBeatDef]:
	var out: Array[FtueBeatDef] = []
	if not enabled():
		return out
	for def: FtueBeatDef in beat_list.beats_for(trigger):
		if _done.has(def.id) or def.max_runs < run_no or def == _active or _queue.has(def):
			continue
		out.append(def)
		if FtueScript.is_silent(def):
			_finish(def)
		elif _active == null:
			_start(def)
		else:
			_queue.append(def)
	return out


## Ends beat `id` (done for good) and starts the next queued one. False when it was already done or unknown.
func complete(id: String) -> bool:
	var def: FtueBeatDef = beat_list.beat(id)
	if def == null or _done.has(id):
		return false
	_finish(def)
	_queue.erase(def)
	if _active == def:
		_active = null
		_next()
	return true


## The player bought upgrade row `upgrade_id`: ends the active beat when it points at that row.
func row_bought(upgrade_id: String) -> bool:
	if _active != null and FtueScript.row_id(_active) == upgrade_id:
		return complete(_active.id)
	return false


## Ends every beat, now and for good (the SKIP HINTS button).
func skip_all() -> void:
	skipped = true
	_active = null
	_queue.clear()
	dirty = true


## Ages the active beat by `dt` seconds of real time and expires it after `DISPLAY_S`. The cold open and the
## results FOUNDRY pulse have no timer (the screen ends the first, the FOUNDRY press the second).
func advance(dt: float) -> void:
	if _active == null:
		return
	if _active.target == FtueScript.TARGET_RESULTS_FOUNDRY or _active.target == FtueScript.TARGET_COLD_OPEN:
		return
	_age_s += dt
	if _age_s >= DISPLAY_S:
		@warning_ignore("return_value_discarded")
		complete(_active.id)


func _start(def: FtueBeatDef) -> void:
	_active = def
	_age_s = 0.0


func _next() -> void:
	_age_s = 0.0
	if not _queue.is_empty():
		_active = _queue.pop_front()


func _finish(def: FtueBeatDef) -> void:
	_done[def.id] = true
	dirty = true


func _read(d: Dictionary) -> void:
	var ids: Variant = d.get("done", [])
	if ids is Array:
		var list: Array = ids
		for v: Variant in list:
			if v is String:
				var id: String = v
				if beat_list.beat(id) != null:
					_done[id] = true
	var flag: Variant = d.get("skipped", false)
	skipped = flag is bool and flag
