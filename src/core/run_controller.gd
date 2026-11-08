class_name RunController
extends RefCounted
## Run state machine (M1-23): BOOT -> IN_RUN -> RESULTS -> (redeploy) IN_RUN. Owns the active SimWorld and its
## TickDriver (TECH_ARCHITECTURE 1.3, 2.2). Plain RefCounted so tests can drive it headless; `Game` owns one
## instance and feeds it `_process` time. Lives in src/core (reads the wall clock for budgets and timing only).
## Debug load mode (M1-25): a run started with `load_wave > 0` is stepped without rendering, in wall-clock
## budgeted chunks per update(), until it reaches that wave, then continues as a normal run.

signal run_started(world: SimWorld)
signal run_ended(world: SimWorld)
signal load_finished(world: SimWorld)

enum State { BOOT, IN_RUN, RESULTS }

const DEFAULT_SEED: int = 1
const LOAD_WAVE: int = 60
## Wall-clock budget per update() while fast-forwarding to the load wave.
const LOAD_BUDGET_USEC: int = 12000
## Ticks stepped between clock checks while fast-forwarding.
const LOAD_CHUNK_TICKS: int = 30

var state: State = State.BOOT
var world: SimWorld
var driver: TickDriver
var seed_value: int = 0
## Game speed multiplier and pause flag (set from the HUD signals).
var speed: int = 1
var paused: bool = false
## Wave the debug load mode is still fast-forwarding to (0 = not loading).
var load_wave: int = 0
## Ticks run and wall microseconds spent by the last update() (debug overlay reads these).
var last_ticks: int = 0
var last_usec: int = 0


## Creates a fresh world for `seed_value` and enters IN_RUN. `invulnerable` and `load_target` are debug-only.
func start_run(new_seed: int, invulnerable: bool = false, load_target: int = 0) -> SimWorld:
	seed_value = new_seed
	var cfg: SimConfig = SimConfigLoader.load_default(new_seed)
	cfg.debug_invulnerable = invulnerable
	world = SimWorld.new(cfg)
	driver = TickDriver.new()
	load_wave = load_target
	last_ticks = 0
	last_usec = 0
	state = State.IN_RUN
	run_started.emit(world)
	return world


## Starts the next deployment with seed = previous seed + 1 (normal rules, no debug flags).
func redeploy() -> SimWorld:
	return start_run(seed_value + 1)


## Per-frame advance. Returns the number of ticks that ran.
func update(delta: float) -> int:
	if state != State.IN_RUN:
		return 0
	var start_usec: int = Time.get_ticks_usec()
	var ran: int = 0
	if load_wave > 0:
		ran = _load_step(start_usec)
	elif paused:
		ran = 0
	else:
		ran = driver.advance(world, delta, speed)
	last_ticks = ran
	last_usec = Time.get_ticks_usec() - start_usec
	_check_over()
	return ran


## Steps up to `max_ticks` ticks immediately (tests, loading); stops when the run ends. Returns ticks run.
func fast_forward(max_ticks: int) -> int:
	var ran: int = 0
	while ran < max_ticks and state == State.IN_RUN and not world.is_over():
		world.step()
		ran += 1
	_check_over()
	return ran


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


func _check_over() -> void:
	if state == State.IN_RUN and world.is_over():
		state = State.RESULTS
		load_wave = 0
		run_ended.emit(world)
