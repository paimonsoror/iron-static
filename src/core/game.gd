extends Node
## Autoload `Game`: app-level singleton (version, boot) and owner of the active run (TECH_ARCHITECTURE 1.3).
## The state machine lives in `RunController` (testable); this node only feeds it frame time and reads the
## debug user args. User args come after `--` on the command line; on Android intent extras are stripped, so
## bake them into the export preset (`command_line/extra_args`, see docs/setup/DEV_ENVIRONMENT.md).
## Debug flags are honoured only in debug builds and are never on by default:
##   --debug-load  restart-style debug scenario: invulnerable run fast-forwarded to wave 60 (M1-25 high load)
##   --debug-perf  emit [PERF] lines every 10 s without opening the debug overlay

const VERSION: String = "0.0.1"
const ARG_DEBUG_LOAD: String = "--debug-load"
const ARG_DEBUG_PERF: String = "--debug-perf"

var controller: RunController = RunController.new()
var debug_load: bool = false
var debug_perf: bool = false
## In-memory best death wave of sector 1 (lives in the controller; persistence arrives in M3).
var best_wave_s1: int:
	get:
		return controller.best_wave_s1
	set(value):
		controller.best_wave_s1 = value


func _ready() -> void:
	Log.info("game boot, version " + VERSION)
	if OS.is_debug_build():
		var args: PackedStringArray = OS.get_cmdline_user_args()
		debug_load = args.has(ARG_DEBUG_LOAD)
		debug_perf = args.has(ARG_DEBUG_PERF)


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


## High-load scenario: invulnerable run, fast-forwarded (unrendered) to wave 60, then played normally.
func start_debug_load() -> void:
	controller.start_run(RunController.DEFAULT_SEED, true, RunController.LOAD_WAVE)
	debug_load = true
	Log.info("run started seed=%d" % controller.seed_value)
	Log.info("debug load: wave=%d invulnerable" % RunController.LOAD_WAVE)


## True when [PERF] lines should be written even with the overlay hidden.
func perf_logging_forced() -> bool:
	return debug_perf or debug_load
