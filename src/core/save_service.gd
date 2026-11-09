class_name SaveService
extends RefCounted
## Owns the profile, its `SaveStore` and the run-snapshot checkpointer (M3-12/13). Loads at boot, banks runs,
## saves on the TECH_ARCHITECTURE 5.3 cadence (`SaveScheduler`) and on app pause, and hands out run seeds
## (Q61: DEFAULT_SEED + run_id - 1). `Game` owns one instance; tests drive it headless on a `MemorySaveFs`.
## Never wipes: CORRUPT and TOO_NEW set `writes_blocked`, so nothing is written until the player acts.

enum Problem { NONE, CORRUPT, TOO_NEW }

const NOTICE_RECOVERED: String = "save.recovered"
const NOTICE_RESUMED: String = "save.resumed"
const NOTICE_ENDED_BY_UPDATE: String = "save.run_ended_by_update"

var profile: PlayerProfile = PlayerProfile.new()
var scheduler: SaveScheduler = SaveScheduler.new()
var checkpointer: RunCheckpointer
var clock: ClockSource
var problem: Problem = Problem.NONE
var writes_blocked: bool = false
var last_error: String = ""
var last_load_status: LoadResult.Status = LoadResult.Status.FRESH
## One-line notice for the UI (a string key); empty when none.
var notice: String = ""
## Frame ids unlocked by the last banked run (the Results chip reads it; empty when none).
var last_unlocked_frames: Array[String] = []
## Mode ids unlocked by the last banked run or by the last load (the Results toast reads it; empty when none).
var last_unlocked_modes: Array[String] = []
## True when the profile save after the last bank succeeded.
var last_bank_saved: bool = false
## Count of successful profile writes (tests).
var writes: int = 0
## Frame table (loaded lazily; tests may inject).
var frame_defs: Array[FrameDef] = []
## Wave mode table (loaded lazily; tests may inject).
var mode_defs: Array[WaveModeDef] = []
var _fs: SaveFs
var _store: SaveStore
var _controller: RunController = null
var _device_id: String
var _retry: bool = false
var _frames_loaded: bool = false
var _modes_loaded: bool = false


func _init(fs: SaveFs, time_source: ClockSource, new_device_id: String) -> void:
	_fs = fs
	clock = time_source
	_device_id = new_device_id
	_store = SaveStore.new(fs, "profile", SaveCodec.MAGIC_PROFILE, SaveSchema.CURRENT)
	checkpointer = RunCheckpointer.new(RunCheckpointer.make_store(fs))


## Loads the profile. FRESH builds a new in-memory profile (nothing written yet); RECOVERED re-saves at once
## and sets the notice; CORRUPT and TOO_NEW block writes and use a fresh in-memory profile.
func load_profile() -> LoadResult.Status:
	var res: LoadResult = _store.load()
	last_load_status = res.status
	problem = Problem.NONE
	writes_blocked = false
	match res.status:
		LoadResult.Status.OK, LoadResult.Status.RECOVERED:
			var doc: Dictionary = SaveSchema.parse_raw(res.raw)
			var up: Dictionary = {"ok": false}
			if not doc.is_empty():
				up = SaveSchema.upgrade(doc, res.schema)
			if not up["ok"]:
				last_error = "profile payload unreadable"
				_block(Problem.CORRUPT)
				last_load_status = LoadResult.Status.CORRUPT
				return last_load_status
			var upgraded: Dictionary = up["doc"]
			profile = SaveSchema.profile_from_document(upgraded)
			if not profile.load_errors.is_empty():
				Log.warn("[SAVE] profile fields repaired: " + "; ".join(profile.load_errors))
			last_unlocked_modes = ModeRules.apply_unlocks(profile, _modes())
			if res.status == LoadResult.Status.RECOVERED:
				notice = NOTICE_RECOVERED
				@warning_ignore("return_value_discarded")  # failure is logged and retried by the scheduler
				save_now()
		LoadResult.Status.FRESH:
			profile = PlayerProfile.fresh(clock.now_utc(), _device_id)
		LoadResult.Status.CORRUPT:
			_block(Problem.CORRUPT)
		LoadResult.Status.TOO_NEW:
			_block(Problem.TOO_NEW)
	return last_load_status


## Player chose START NEW PROFILE on the Save problem screen: damaged files are renamed `*.corrupt` and
## writes are allowed again. Refused (false) for TOO_NEW: only updating the app helps.
func resolve_start_new() -> bool:
	if problem != Problem.CORRUPT:
		return false
	if not _store.quarantine():
		last_error = "quarantine failed"
		return false
	@warning_ignore("return_value_discarded")  # a stale snapshot may not exist
	checkpointer.store.quarantine()
	profile = PlayerProfile.fresh(clock.now_utc(), _device_id)
	problem = Problem.NONE
	writes_blocked = false
	last_load_status = LoadResult.Status.FRESH
	return true


## NEW GAME / Settings > Data (Q66): renames every profile and run-snapshot file (live, bak, tmp) to
## `<file>.reset` (numbered, never overwriting, never deleting), then starts a fresh in-memory profile that keeps
## the old settings. Writes nothing itself: the caller saves (`save_now`) so the settings survive a restart.
## Refused (false) while writes are blocked (save problem) or when a rename fails.
func reset_profile() -> bool:
	if writes_blocked:
		return false
	var stores: Array[SaveStore] = [_store, checkpointer.store]
	for st: SaveStore in stores:
		for p: String in [st.live_path(), st.bak_path(), st.tmp_path()]:
			if _fs.exists(p) and not _fs.rename(p, _reset_target(p)):
				last_error = "reset rename failed"
				return false
	var kept: Dictionary = profile.settings.duplicate(true)
	profile = PlayerProfile.fresh(clock.now_utc(), _device_id)
	profile.settings = kept
	if _controller != null:
		_controller.best_wave_s1 = 0  # the session value mirrors the old profile's best wave
	scheduler.notify_saved()
	notice = ""
	last_unlocked_frames = []
	last_unlocked_modes = []
	last_bank_saved = false
	last_error = ""
	last_load_status = LoadResult.Status.FRESH
	return true


## Marks state worth saving; the write happens after the 2 s debounce (`tick`).
func request_save() -> void:
	scheduler.request_save()


## Synchronous atomic write of the profile (purchases, run end, app pause). False when blocked or failed.
func save_now() -> bool:
	if writes_blocked:
		return false
	var t0: int = Time.get_ticks_msec()
	profile.touch(clock.now_utc())
	var raw: PackedByteArray = SaveSchema.raw_from_document(SaveSchema.document_from_profile(profile))
	var ok: bool = _store.save(SaveSchema.CURRENT, raw)
	var ms: int = Time.get_ticks_msec() - t0
	if ok:
		writes += 1
		last_error = ""
		scheduler.notify_saved()
		_retry = false
		Log.info("[SAVE] ok live %d bytes %d ms" % [raw.size(), ms])
	else:
		last_error = "profile write failed"
		_retry = true
		Log.warn("[SAVE] failed live %d bytes %d ms" % [raw.size(), ms])
	return ok


## Binds the run controller (run end banking, checkpoint cadence).
func attach(controller: RunController) -> void:
	_controller = controller
	controller.run_ended.connect(_on_run_ended)


## Per-frame: advances the scheduler, writes what is due. A failed write retries once on the next tick.
func tick(dt: float) -> int:
	var in_run: bool = _controller != null and _checkpointable()
	var in_menu: bool = _controller == null or _controller.state != RunController.State.IN_RUN
	var paused: bool = _controller != null and _controller.paused
	var flags: int = scheduler.advance(dt, in_menu, in_run, paused)
	if _retry:
		_retry = false
		flags |= SaveScheduler.FLAG_SAVE
	if flags & SaveScheduler.FLAG_SAVE:
		@warning_ignore("return_value_discarded")  # failure is recorded in last_error and retried once
		save_now()
	if flags & SaveScheduler.FLAG_CHECKPOINT:
		@warning_ignore("return_value_discarded")
		checkpoint_now()
	return flags


## Starts a normal deployment: next run id from the profile, Q61 seed, Foundry levels and the selected frame.
## The controller's current `best_wave_s1` (a debug override, session only) can only raise the profile's.
func start_run() -> SimWorld:
	var run_id: int = profile.begin_run()
	request_save()
	var best: int = maxi(profile.best_wave_s1(), _controller.best_wave_s1)
	_controller.best_wave_s1 = best
	var run_seed: int = RunController.DEFAULT_SEED + run_id - 1
	var frame_id: String = FrameRules.selected_id(profile, _frames())
	return _controller.start_run(run_seed, false, 0, profile.foundry, run_id, frame_id)


## Banks a finished run (`FrameRules.bank`: profile bank plus frame unlocks), saves synchronously and only
## then deletes the run snapshot. True when the run was banked (false for debug runs and duplicates).
func bank_run(summary: RunSummary) -> bool:
	var before: int = profile.last_banked_run
	last_unlocked_frames = FrameRules.bank(profile, summary, _frames())
	var banked: bool = profile.last_banked_run != before
	last_bank_saved = false
	last_unlocked_modes = []
	if not banked:
		return false
	last_unlocked_modes = ModeRules.apply_unlocks(profile, _modes())
	last_bank_saved = save_now()
	if last_bank_saved:
		@warning_ignore("return_value_discarded")  # a stale snapshot is deleted at boot by the run id rule
		checkpointer.clear()
	return true


## Writes a run checkpoint of the controller's world (normal runs only). False when not applicable.
func checkpoint_now() -> bool:
	if _controller == null or not _checkpointable():
		return false
	var ok: bool = checkpointer.checkpoint(_controller.world, _controller.run_id)
	if ok:
		scheduler.notify_checkpointed()
	return ok


## App going to the background or closing: profile first, then the run checkpoint (between ticks).
func flush_for_background() -> void:
	@warning_ignore("return_value_discarded")  # logged inside; nothing more to do on failure here
	save_now()
	@warning_ignore("return_value_discarded")
	checkpoint_now()


## Boot: rebuilds an interrupted run from the snapshot. `cfg_factory` is `func(info: SnapshotInfo) -> SimConfig`.
## RESUMED returns the world (the caller passes it to `RunController.resume_run`); an update mismatch banks the
## interrupted run's data once and sets the notice. Never blocks the profile.
func try_resume(cfg_factory: Callable) -> ResumeResult:
	var res: ResumeResult = checkpointer.try_resume(cfg_factory, profile.last_banked_run)
	match res.status:
		ResumeResult.Status.RESUMED:
			notice = NOTICE_RESUMED
		ResumeResult.Status.ENDED_BY_UPDATE:
			var s: RunSummary = RunSummary.make(res.info.run_id, res.info.wave, res.data_run, res.info.tick)
			@warning_ignore("return_value_discarded")  # a duplicate run id is simply not banked again
			bank_run(s)
			notice = NOTICE_ENDED_BY_UPDATE
	return res


## RunSummary of a finished world (run id and `counts_for_progress` come from the controller).
static func summary_from(world: SimWorld, run_id: int, counts: bool) -> RunSummary:
	var s: RunSummary = RunSummary.make(
		run_id, world.run.death_wave, world.economy.data_run, world.tick, world.run.kills, world.config.sector
	)
	s.mode = world.config.wave_mode
	s.counts_for_progress = counts
	return s


func _on_run_ended(world: SimWorld) -> void:
	var counts: bool = _controller.banks_rewards() and _controller.run_id > 0
	@warning_ignore("return_value_discarded")  # banking outcome is in last_bank_saved / last_unlocked_frames
	bank_run(summary_from(world, _controller.run_id, counts))


func _checkpointable() -> bool:
	return (
		_controller.state == RunController.State.IN_RUN
		and _controller.banks_rewards()
		and _controller.run_id > 0
		and _controller.load_wave == 0
		and _controller.world != null
		and not _controller.world.is_over()
	)


func _block(p: Problem) -> void:
	problem = p
	writes_blocked = true
	profile = PlayerProfile.fresh(clock.now_utc(), _device_id)


func _frames() -> Array[FrameDef]:
	if not _frames_loaded:
		if frame_defs.is_empty():
			frame_defs = FrameRules.load_defs()
		_frames_loaded = true
	return frame_defs


func _modes() -> Array[WaveModeDef]:
	if not _modes_loaded:
		if mode_defs.is_empty():
			mode_defs = ModeRules.load_defs()
		_modes_loaded = true
	return mode_defs


## `<path>.reset`, numbered (`.reset.1`, ...) so an earlier reset's files are never overwritten.
func _reset_target(path: String) -> String:
	var target: String = path + ".reset"
	var k: int = 0
	while _fs.exists(target):
		k += 1
		target = path + ".reset." + str(k)
	return target
