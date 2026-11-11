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
##   --mode <id>|--mode=<id>  start every run in that wave mode, ignoring the lock (M4-08, e.g. `--mode purge`)
## Save arg (all builds): --no-save keeps the profile and run snapshot in memory (tests, tools; M3-14).

const VERSION: String = "0.5.1-beta.1"
const ARG_DEBUG_LOAD: String = "--debug-load"
const ARG_DEBUG_PERF: String = "--debug-perf"
const ARG_STYLE_FRAME: String = "--style-frame"
const ARG_LOAD_WAVE: String = "--debug-load-wave="
const ARG_HOLD: String = "--debug-hold"
const ARG_NOVSYNC: String = "--debug-novsync"
const ARG_NO_SAVE: String = "--no-save"
const ARG_MODE: String = "--mode"
const PLAY_FLUSH_S: int = 30

var controller: RunController = RunController.new()
var debug_load: bool = false
var debug_perf: bool = false
## Debug load target wave (RunController.LOAD_WAVE unless `--debug-load-wave=` says otherwise).
var debug_load_wave: int = RunController.LOAD_WAVE
## Pause the sim when the debug load wave is reached.
var debug_hold: bool = false
## Debug wave mode override (`--mode purge`, debug builds only): ignores the unlock; "" = use the profile.
var mode_override: String = ""
## True when the V1-01 style frame scene replaces the game at boot (debug builds, `--style-frame`).
var style_frame: bool = false
## View-side quality tier and visual options (handed to the view by main.gd; never read by the sim).
var visual: VisualSettings = VisualSettings.new()
## SFX and adaptive music (A1). Presentation only: never read by the sim; phase-2 hooks call into it.
var audio: AudioDirector = AudioDirector.new()
## Haptic pulses (M4-22): device motor on Android, no-op on desktop; `enabled` is the haptics setting (M4-23).
var haptics: Haptics = Haptics.create()
## Persistence (M3-12, no autoloads added): the profile lives in `saves.profile`.
var saves: SaveService
var clock: ClockSource = SystemClock.new()
var settings_applier: SettingsApplier = SettingsApplier.new()
## One-line notice key for the UI (`save.recovered`, `save.resumed`, `save.run_ended_by_update`); M3-14 shows it.
var notice: String = ""
## The profile file is damaged or too new: `SaveService.Problem` (NONE when fine). M3-14 shows the screen.
var save_problem: SaveService.Problem = SaveService.Problem.NONE
## Best death wave of sector 1 for this session (lives in the controller; raised from the profile at run start).
var best_wave_s1: int:
	get:
		return controller.best_wave_s1
	set(value):
		controller.best_wave_s1 = value
var _pending_resume: ResumeResult = null
var _was_paused: bool = false
## Foreground play time (R1-08 flight recorder and the Service Record): sampled each frame through the clock, written in
## whole seconds, at least every 30 s and whenever the app goes to the background (background time never counts).
var _play_timer: PlayTimer = PlayTimer.new()
var _play_flush_at_ms: int = 0


func _ready() -> void:
	Log.info("game boot, version " + VERSION)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	visual = VisualSettings.from_args(args)
	if OS.is_debug_build():
		debug_load = args.has(ARG_DEBUG_LOAD)
		debug_perf = args.has(ARG_DEBUG_PERF)
		style_frame = args.has(ARG_STYLE_FRAME)
		debug_hold = args.has(ARG_HOLD)
		mode_override = mode_from_args(args)
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
	# --no-save (tests, tools): an in-memory fs, so a run never reads or writes the real user://save profile.
	var fs: SaveFs = MemorySaveFs.new() if args.has(ARG_NO_SAVE) else DiskSaveFs.new()
	setup_persistence(fs, args)


func _process(delta: float) -> void:
	controller.update(delta)
	_count_play_time()
	if saves != null:
		if controller.paused and not _was_paused:
			@warning_ignore("return_value_discarded")  # the pause overlay opened: checkpoint between ticks
			saves.checkpoint_now()
		_was_paused = controller.paused
		@warning_ignore("return_value_discarded")
		saves.tick(delta)


## Lifecycle saves (TECH_ARCHITECTURE 2.8 / 5.3, V1-24): synchronous, between ticks. Desktop focus changes do
## not save (same rule as the pause); closing the window does.
func _notification(what: int) -> void:
	if saves == null:
		return
	var flush: bool = (
		what == NOTIFICATION_APPLICATION_PAUSED
		or what == NOTIFICATION_WM_GO_BACK_REQUEST
		or what == NOTIFICATION_WM_CLOSE_REQUEST
		or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile"))
	)
	if flush:
		_flush_play_time()
		_play_timer.suspend()
		saves.flush_for_background()


## Boot persistence (also called by tests with a `MemorySaveFs`): builds the service, loads the profile,
## applies the settings, then prepares a resume of an interrupted run. Never blocks on a bad snapshot.
func setup_persistence(fs: SaveFs, args: PackedStringArray) -> void:
	saves = SaveService.new(fs, clock, Crypto.new().generate_random_bytes(16).hex_encode())
	saves.attach(controller)
	controller.run_ended.connect(_on_run_ended)  # after the service's own banking handler
	controller.run_aborted.connect(_on_run_ended)
	var status: LoadResult.Status = saves.load_profile()
	save_problem = saves.problem
	notice = saves.notice
	_note_session()
	if not saves.last_unlocked_modes.is_empty():  # a mode the load itself unlocked (migrated save): same one-time chip
		ModeUnlockFlag.mark(saves.profile, saves.last_unlocked_modes)
		saves.request_save()
	Log.info("[SAVE] boot load status=%s problem=%s" % [LoadResult.Status.keys()[status], str(save_problem)])
	settings_applier.haptics = haptics
	settings_applier.apply(PlayerSettings.from_dict(saves.profile.settings), visual, audio.settings, args)
	if save_problem == SaveService.Problem.NONE and not debug_load and not style_frame:
		_pending_resume = saves.try_resume(_resume_config)
		if saves.notice != notice:
			notice = saves.notice


## The profile (`saves.profile`).
func profile() -> PlayerProfile:
	return saves.profile


## True when boot found an interrupted run: `start_run()` will resume it (paused) instead of starting a new one.
func has_pending_resume() -> bool:
	return _pending_resume != null and _pending_resume.status == ResumeResult.Status.RESUMED


## Drops the interrupted run found at boot (profile reset: NEW GAME, Settings > Data).
func discard_pending_resume() -> void:
	_pending_resume = null


## Hook after a run was banked and its profile save returned true (the snapshot is already cleared by
## `SaveService.bank_run`, in that order); M3-14/17 may extend it.
func on_run_banked() -> void:
	Log.info("run banked unlocked=%s" % str(saves.last_unlocked_frames))


@warning_ignore("unused_parameter")
func _on_run_ended(ended_world: SimWorld) -> void:  # gdlint: ignore=unused-argument
	if not saves.last_unlocked_modes.is_empty():  # Home shows the one-time "MODE UNLOCKED" chip (M4-08)
		ModeUnlockFlag.mark(saves.profile, saves.last_unlocked_modes)
		saves.request_save()
	if _records_play():
		FlightRecorder.note_run(saves.profile, clock, ended_world.config.wave_mode, ended_world.wave)
		saves.request_save()
	if saves.last_bank_saved:
		on_run_banked()


func _resume_config(info: SnapshotInfo) -> SimConfig:
	var cfg: SimConfig = SimConfigLoader.load_default(info.seed_value)
	cfg.best_wave_s1 = info.best_wave_s1
	cfg.debug_invulnerable = info.debug_invulnerable
	SimConfigLoader.apply_foundry(cfg, saves.profile.foundry)
	@warning_ignore("return_value_discarded")  # unknown mode: config stays timed, restore refuses it (ENDED_BY_UPDATE)
	SimConfigLoader.apply_mode(cfg, info.wave_mode)
	if info.frame_id != PlayerProfile.DEFAULT_FRAME:
		@warning_ignore("return_value_discarded")  # unknown frame id: config stays VANGUARD, restore refuses it
		SimConfigLoader.apply_frame(cfg, info.frame_id)
	return cfg


## Upgrade panel purchase: queued, applied at the start of the next controller update (see RunController).
func request_buy(upgrade_index: int, count: int) -> void:
	@warning_ignore("return_value_discarded")
	controller.request_buy(upgrade_index, count)


## Starts a normal deployment. At boot a pending run snapshot resumes instead (paused behind the overlay).
## The seed is DEFAULT_SEED + run id - 1 (Q61), the id from the profile. `mode` is the wave mode id; "" takes the
## profile's `last_mode` (REDEPLOY therefore repeats it, Q75). A locked mode is never used (`RunMode.resolve`);
## the `--mode` debug override wins and ignores the lock.
func start_run(mode: String = "") -> void:
	if _pending_resume != null and _pending_resume.status == ResumeResult.Status.RESUMED:
		var res: ResumeResult = _pending_resume
		_pending_resume = null
		@warning_ignore("return_value_discarded")
		controller.resume_run(res.world, res.info.run_id, res.extras)
		Log.info("run resumed run=%d tick=%d" % [res.info.run_id, res.world.tick])
		return
	_pending_resume = null
	var run_mode: String = RunMode.resolve(saves.profile, mode, mode_override)
	var best_before: int = saves.profile.best_wave_of_mode(run_mode, 1)
	@warning_ignore("return_value_discarded")
	saves.start_run(run_mode)
	controller.mode_best_at_start = best_before  # Results: "NEW BEST" is per mode (M4-09)
	Log.info(
		(
			"run started seed=%d run=%d mode=%s"
			% [controller.seed_value, controller.run_id, controller.world.config.wave_mode]
		)
	)


## Value of `--mode <id>` or `--mode=<id>` in the user args ("" when absent).
static func mode_from_args(args: PackedStringArray) -> String:
	for i: int in args.size():
		if args[i] == ARG_MODE and i + 1 < args.size():
			return args[i + 1]
		if args[i].begins_with(ARG_MODE + "="):
			return args[i].substr(ARG_MODE.length() + 1)
	return ""


## Starts the next deployment (next run id, Foundry levels from the profile).
func redeploy() -> void:
	start_run()


## High-load scenario: invulnerable run, fast-forwarded (unrendered) to `wave` (default `debug_load_wave`, 60),
## then played normally (or paused by main.gd when `debug_hold` is set).
func start_debug_load(wave: int = 0) -> void:
	if wave > 0:
		debug_load_wave = wave
	controller.paused = false
	# The load run follows the mode the player would get (`--mode` override, else the profile's last mode), so the
	# stress scene can be measured in PURGE too (M4-28); a fresh profile stays TIMED.
	var load_mode: String = RunMode.resolve(saves.profile, "", mode_override) if saves != null else mode_override
	controller.start_run(RunController.DEFAULT_SEED, true, debug_load_wave, {}, 0, "", load_mode)
	debug_load = true
	Log.info("run started seed=%d" % controller.seed_value)
	Log.info("debug load: wave=%d invulnerable" % debug_load_wave)


## True when [PERF] lines should be written even with the overlay hidden.
func perf_logging_forced() -> bool:
	return debug_perf or debug_load


## True when play is recorded locally (R1-08): a real profile, not a debug load or tool run.
func _records_play() -> bool:
	return saves != null and save_problem == SaveService.Problem.NONE and not debug_load and not style_frame


func _note_session() -> void:
	if _records_play():
		FlightRecorder.note_session(saves.profile, clock)
		saves.request_save()


## The player is on `screen` (an `AppFlow.Screen` name, lower case): deepest and last screen of the day.
func note_screen(screen: String) -> void:
	if _records_play():
		FlightRecorder.note_screen(saves.profile, clock, screen)
		saves.request_save()


func _count_play_time() -> void:
	_play_timer.sample(clock)
	if clock.monotonic_ms() - _play_flush_at_ms >= PLAY_FLUSH_S * 1000:
		_flush_play_time()


## Writes the whole seconds counted so far into today's flight record and the Service Record (the profile save follows
## with the next save). Seconds counted while play is not recorded (a debug load, a save problem) are dropped.
func _flush_play_time() -> void:
	_play_flush_at_ms = clock.monotonic_ms()
	var whole: int = _play_timer.take_seconds()
	if whole <= 0 or not _records_play():
		return
	FlightRecorder.note_seconds(saves.profile, clock, whole)
	ServiceRecord.note_seconds(saves.profile, whole)
