extends Node
## Autoload `Game`: app-level singleton (version, boot) and owner of the active run (TECH_ARCHITECTURE 1.3).
## The state machine lives in `RunController` (testable); this node only feeds it frame time and reads the
## debug user args. User args come after `--` on the command line; on Android intent extras are stripped, so
## bake them into the export preset (`command_line/extra_args`, see docs/setup/DEV_ENVIRONMENT.md).
## Debug flags are honoured only in debug builds and are never on by default:
##   --debug-load  restart-style debug scenario: invulnerable run fast-forwarded to wave 60 (M1-25 high load)
##   --debug-perf  emit [PERF] lines every 10 s without opening the debug overlay
##   --debug-load-wave=<n>  with --debug-load: fast-forward to wave n instead of 60 (14 ~ 40 enemies, 19 ~ 100)
##   --debug-hold  pause the sim when the load wave is reached (static crowd: render cost without sim cost)
##   --debug-novsync  disable vsync so fps shows uncapped render throughput (V1-03 bench)
## Quality args (all builds): --quality=high|mid|low, --shake=off|low|normal (VisualSettings, V1-03).
## Audio arg (all builds): --mute runs silent (no SFX, no music; benches and captures).

const VERSION: String = "0.0.1"
const ARG_DEBUG_LOAD: String = "--debug-load"
const ARG_DEBUG_PERF: String = "--debug-perf"
const ARG_STYLE_FRAME: String = "--style-frame"
const ARG_LOAD_WAVE: String = "--debug-load-wave="
const ARG_HOLD: String = "--debug-hold"
const ARG_NOVSYNC: String = "--debug-novsync"

var controller: RunController = RunController.new()
var debug_load: bool = false
var debug_perf: bool = false
## Debug load target wave (RunController.LOAD_WAVE unless `--debug-load-wave=` says otherwise).
var debug_load_wave: int = RunController.LOAD_WAVE
## Pause the sim when the debug load wave is reached.
var debug_hold: bool = false
## True when the V1-01 style frame scene replaces the game at boot (debug builds, `--style-frame`).
var style_frame: bool = false
## View-side quality tier and visual options (handed to the view by main.gd; never read by the sim).
var visual: VisualSettings = VisualSettings.new()
## SFX and adaptive music (A1). Presentation only: never read by the sim; phase-2 hooks call into it.
var audio: AudioDirector = AudioDirector.new()
## In-memory best death wave of sector 1 (lives in the controller; persistence arrives in M3).
var best_wave_s1: int:
	get:
		return controller.best_wave_s1
	set(value):
		controller.best_wave_s1 = value


func _ready() -> void:
	Log.info("game boot, version " + VERSION)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	visual = VisualSettings.from_args(args)
	if OS.is_debug_build():
		debug_load = args.has(ARG_DEBUG_LOAD)
		debug_perf = args.has(ARG_DEBUG_PERF)
		style_frame = args.has(ARG_STYLE_FRAME)
		debug_hold = args.has(ARG_HOLD)
		for a: String in args:
			if a.begins_with(ARG_LOAD_WAVE):
				debug_load_wave = clampi(a.substr(ARG_LOAD_WAVE.length()).to_int(), 2, 200)
		if args.has(ARG_NOVSYNC):
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			visual.fps_cap = 0  # the bench measures uncapped throughput
	visual.apply_fps_cap()
	add_child(audio)
	if AudioSettings.is_mute_arg(args):
		audio.disabled = true
		audio.settings.muted = true
	audio.setup()


func _process(delta: float) -> void:
	controller.update(delta)


## Upgrade panel purchase: queued, applied at the start of the next controller update (see RunController).
func request_buy(upgrade_index: int, count: int) -> void:
	@warning_ignore("return_value_discarded")
	controller.request_buy(upgrade_index, count)


## Starts a normal deployment with `seed_value` (first run: RunController.DEFAULT_SEED, then +1 per redeploy).
func start_run(seed_value: int) -> void:
	controller.start_run(seed_value)
	Log.info("run started seed=%d" % seed_value)


## Starts the next deployment (seed + 1).
func redeploy() -> void:
	controller.redeploy()
	Log.info("run started seed=%d" % controller.seed_value)


## High-load scenario: invulnerable run, fast-forwarded (unrendered) to `wave` (default `debug_load_wave`, 60),
## then played normally (or paused by main.gd when `debug_hold` is set).
func start_debug_load(wave: int = 0) -> void:
	if wave > 0:
		debug_load_wave = wave
	controller.paused = false
	controller.start_run(RunController.DEFAULT_SEED, true, debug_load_wave)
	debug_load = true
	Log.info("run started seed=%d" % controller.seed_value)
	Log.info("debug load: wave=%d invulnerable" % debug_load_wave)


## True when [PERF] lines should be written even with the overlay hidden.
func perf_logging_forced() -> bool:
	return debug_perf or debug_load
