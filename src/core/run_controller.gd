class_name RunController
extends RefCounted
## Run state machine (M1-23): BOOT -> IN_RUN -> RESULTS -> (redeploy) IN_RUN. Owns the active SimWorld and its
## TickDriver (TECH_ARCHITECTURE 1.3, 2.2). Plain RefCounted so tests can drive it headless; `Game` owns one
## instance and feeds it `_process` time. Lives in src/core (reads the wall clock for budgets and timing only).
## Debug load mode (M1-25): a run started with `load_wave > 0` is stepped without rendering, in wall-clock
## budgeted chunks per update(), until it reaches that wave, then continues as a normal run.
## Buys (M2-12): `request_buy` only queues; the queue is applied at the START of the next update() (or
## fast_forward()), before the driver advances, so `command_buy` never runs inside `driver.advance` and each
## buy is logged at the tick about to run. While paused the tick does not move, so buys land on the current
## tick (accepted, applied at the next update()). Requests during RESULTS or the debug load fast-forward are
## dropped (impl). At run end the best wave is updated (not for load runs) and `last_run.json` is written.

signal run_started(world: SimWorld)
signal run_ended(world: SimWorld)
## The player aborted a live run from the pause menu (the world is NOT over). Subscribers bank it exactly like
## `run_ended` (SaveService, Game); the UI goes straight Home instead of Results.
signal run_aborted(world: SimWorld)
signal load_finished(world: SimWorld)

enum State { BOOT, IN_RUN, RESULTS }

const DEFAULT_SEED: int = 1
const LOAD_WAVE: int = 60
## Wall-clock budget per update() while fast-forwarding to the load wave.
const LOAD_BUDGET_USEC: int = 12000
## Ticks stepped between clock checks while fast-forwarding.
const LOAD_CHUNK_TICKS: int = 30
const LAST_RUN_DIR: String = "user://runs"
const LAST_RUN_FILE: String = "last_run.json"

var state: State = State.BOOT
var world: SimWorld
var driver: TickDriver
var seed_value: int = 0
## Game speed multiplier and pause flag (set from the HUD signals).
var speed: int = 1
var paused: bool = false
## View-only pacing factor (slow-mo, V1-14) multiplied into the frame delta given to the driver: fewer ticks per
## wall second, identical tick content. 1.0 = normal. Never read by the sim; reset to 1.0 at run start.
var time_scale: float = 1.0
## Wave the debug load mode is still fast-forwarding to (0 = not loading).
var load_wave: int = 0
## Ticks run and wall microseconds spent by the last update() (debug overlay reads these).
var last_ticks: int = 0
var last_usec: int = 0
## In-memory best death wave of sector 1 (persistence arrives in M3); copied into SimConfig at run start.
var best_wave_s1: int = 0
## Best wave of the run's own mode at its start (Game sets it for PURGE-style records; -1 = unknown, e.g. a resumed
## run): the Results screen compares the death wave against it (M4-09).
var mode_best_at_start: int = -1
## Where the run record is written at run end (tests override it).
var last_run_path: String = LAST_RUN_DIR + "/" + LAST_RUN_FILE
## Persistent run id (profile run counter, M3-12); 0 for debug and bare test runs.
var run_id: int = 0
## Headless and debug paths: settle an open draft with the first offer between frames (logged like a player pick, so
## records and replays stay exact). The game turns it OFF (main.gd, M4-16) and shows `DraftOverlay` instead; tests and
## bare controllers keep it on. The debug load fast-forward settles regardless (nothing renders, nobody could pick).
var auto_pick_draft: bool = true
var _pending_buys: Array[Vector2i] = []
var _load_run: bool = false


## Creates a fresh world for `seed_value` and enters IN_RUN. `invulnerable` and `load_target` are debug-only.
func start_run(
	new_seed: int,
	invulnerable: bool = false,
	load_target: int = 0,
	foundry_levels: Dictionary = {},
	new_run_id: int = 0,
	frame_id: String = "",
	mode: String = "",
) -> SimWorld:
	seed_value = new_seed
	run_id = new_run_id
	mode_best_at_start = -1
	var cfg: SimConfig = SimConfigLoader.load_default(new_seed)
	cfg.debug_invulnerable = invulnerable
	cfg.best_wave_s1 = best_wave_s1
	if not foundry_levels.is_empty():
		SimConfigLoader.apply_foundry(cfg, foundry_levels)
	if not frame_id.is_empty() and frame_id != PlayerProfile.DEFAULT_FRAME:
		var applied: bool = SimConfigLoader.apply_frame(cfg, frame_id)  # unknown id: push_error, stays VANGUARD
		if not applied:
			Log.warn("run start: frame '%s' not applied" % frame_id)
	if not mode.is_empty():
		var mode_errors: PackedStringArray = SimConfigLoader.apply_mode(cfg, mode)  # unknown id: stays TIMED, no push_error
		if not mode_errors.is_empty():
			Log.warn("run start: " + mode_errors[0])
	world = SimWorld.new(cfg)
	driver = TickDriver.new()
	load_wave = load_target
	time_scale = 1.0
	_load_run = invulnerable or load_target > 0
	_pending_buys.clear()
	last_ticks = 0
	last_usec = 0
	state = State.IN_RUN
	run_started.emit(world)
	return world


## Starts the next deployment with seed = previous seed + 1 (normal rules, no debug flags).
func redeploy() -> SimWorld:
	return start_run(seed_value + 1)


## True when this run's result counts for the profile (not a debug-load or invulnerable run).
func banks_rewards() -> bool:
	return not _load_run


## Enters IN_RUN on a world rebuilt from a run snapshot (M3-13). Resumes PAUSED: the player taps to continue.
func resume_run(restored: SimWorld, resumed_run_id: int) -> SimWorld:
	world = restored
	seed_value = restored.config.seed_value
	run_id = resumed_run_id
	mode_best_at_start = -1
	driver = TickDriver.new()
	load_wave = 0
	time_scale = 1.0
	_load_run = false
	_pending_buys.clear()
	last_ticks = 0
	last_usec = 0
	paused = true
	state = State.IN_RUN
	run_started.emit(world)
	return world


## Queues a purchase from the UI (applied at the start of the next update()). Returns false when dropped.
func request_buy(upgrade_index: int, count: int) -> bool:
	if state != State.IN_RUN or load_wave > 0:
		return false
	_pending_buys.append(Vector2i(upgrade_index, count))
	return true


## Per-frame advance. Returns the number of ticks that ran.
func update(delta: float) -> int:
	if state != State.IN_RUN:
		return 0
	var start_usec: int = Time.get_ticks_usec()
	var ran: int = 0
	_apply_pending_buys()
	if load_wave > 0:
		ran = _load_step(start_usec)
	elif paused:
		ran = 0
	else:
		ran = driver.advance(world, delta * time_scale, speed)
	_settle_draft()
	last_ticks = ran
	last_usec = Time.get_ticks_usec() - start_usec
	_check_over()
	return ran


## Steps up to `max_ticks` ticks immediately (tests, loading); stops when the run ends. Returns ticks run.
func fast_forward(max_ticks: int) -> int:
	var ran: int = 0
	_apply_pending_buys()
	while ran < max_ticks and state == State.IN_RUN and not world.is_over():
		_settle_draft()
		world.step()
		ran += 1
	_check_over()
	return ran


## Ends the live run at the current tick as if Cinder fell (pause menu ABORT MISSION): the record is written
## (`"ended":"aborted"`), the session best is raised for TIMED, `run_aborted` fires so the run is banked. The sim
## world is left untouched (no end_run, so replay hashes stay the live world's). False when there is no live run
## (not IN_RUN, already over, debug load).
func abort_run() -> bool:
	if state != State.IN_RUN or world == null or world.is_over() or load_wave > 0:
		return false
	state = State.RESULTS
	_pending_buys.clear()
	_finish(true)
	run_aborted.emit(world)
	return true


## Fraction (0-1) of the debug load reached so far, 1.0 when not loading.
func load_progress() -> float:
	if load_wave <= 0:
		return 1.0
	return clampf(float(world.wave - 1) / float(load_wave - 1), 0.0, 1.0)


## mm:ss for a tick count (game time, 30 ticks per second).
static func time_text(ticks: int) -> String:
	var total_s: int = floori(float(maxi(ticks, 0)) / float(Ticks.TICK_RATE))
	return "%02d:%02d" % [floori(float(total_s) / 60.0), total_s % 60]


## Upper-case enemy type name of the killer, or "UNKNOWN" (no killer recorded).
static func cause_text(w: SimWorld) -> String:
	var idx: int = w.run.death_cause
	if idx < 0 or idx >= w.config.enemies.size():
		return "UNKNOWN"
	var def: EnemyDef = w.config.enemies[idx]
	return def.id.to_upper()


func _load_step(start_usec: int) -> int:
	var ran: int = 0
	while load_wave > 0 and not world.is_over():
		var chunk: int = 0
		while chunk < LOAD_CHUNK_TICKS and world.wave < load_wave and not world.is_over():
			_settle_draft(true)
			world.step()
			chunk += 1
		ran += chunk
		if world.wave >= load_wave:
			load_wave = 0
			load_finished.emit(world)
			break
		if Time.get_ticks_usec() - start_usec >= LOAD_BUDGET_USEC:
			break
	return ran


func _apply_pending_buys() -> void:
	if _pending_buys.is_empty():
		return
	if world != null and state == State.IN_RUN and load_wave == 0:
		for req: Vector2i in _pending_buys:
			@warning_ignore("return_value_discarded")  # rejections (unaffordable, locked) are simply not logged
			world.command_buy(req.x, req.y)
	_pending_buys.clear()


func _write_last_run(w: SimWorld, aborted: bool = false) -> void:
	var dir_path: String = last_run_path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(dir_path) != OK:
		Log.warn("run record: cannot create " + dir_path)
		return
	var file: FileAccess = FileAccess.open(last_run_path, FileAccess.WRITE)
	if file == null:
		Log.warn("run record: cannot write " + last_run_path)
		return
	file.store_string(RunRecord.from_world(w, aborted).to_json())
	file.close()
	Log.info("run record written: " + ProjectSettings.globalize_path(last_run_path))


func _check_over() -> void:
	if state == State.IN_RUN and world.is_over():
		state = State.RESULTS
		_pending_buys.clear()
		_finish(false)
		run_ended.emit(world)


## Shared end-of-run bookkeeping (a death and an abort): session best (TIMED only, Q71) and the run record.
func _finish(aborted: bool) -> void:
	load_wave = 0
	var wave: int = world.wave if aborted else world.run.death_wave
	if not _load_run and world.config.wave_mode == SimConfig.MODE_TIMED:
		best_wave_s1 = maxi(best_wave_s1, wave)
	_write_last_run(world, aborted)


## Takes the first offer of an open draft when `auto_pick_draft` is on (or `force`: the debug load). Runs between
## frames and before each step of the loops above, never inside `driver.advance`.
func _settle_draft(force: bool = false) -> void:
	if (auto_pick_draft or force) and world != null and world.is_draft_open():
		@warning_ignore("return_value_discarded")
		world.command_pick(0)
