class_name RunCheckpointer
extends RefCounted
## Run checkpoint and resume (M3-13, TECH_ARCHITECTURE 5.3). Captures a `SimSnapshot` between ticks, wraps it
## with `SaveCodec` (magic ISNP) and stores it in the `run_snapshot` `SaveStore`. `try_resume` decodes it and
## classifies the outcome; the caller (SaveService) banks and clears. (impl) capture, encode and write run
## synchronously on the main thread: the ms are logged in the `[CHECKPOINT]` line so a threaded write can
## be added if a device measures over budget.

const STORE_NAME: String = "run_snapshot"
const SNAPSHOT_SCHEMA: int = 1

var store: SaveStore
## Hash and tick of the last successful checkpoint (tests compare them with `[RESUME]`).
var last_hash: String = ""
var last_tick: int = -1
var last_bytes: int = 0
var last_ms: int = 0
## Each log line is also kept here (tests assert on it; Log keeps a ring buffer of its own).
var log_lines: PackedStringArray = PackedStringArray()


func _init(snapshot_store: SaveStore) -> void:
	store = snapshot_store


static func make_store(fs: SaveFs) -> SaveStore:
	return SaveStore.new(fs, STORE_NAME, SaveCodec.MAGIC_SNAPSHOT, SNAPSHOT_SCHEMA)


## Writes a checkpoint of `world`. Call only between ticks. False when the write failed (the previous one
## stays loadable).
func checkpoint(world: SimWorld, run_id: int) -> bool:
	var t0: int = Time.get_ticks_msec()
	var raw: PackedByteArray = SimSnapshot.capture(world, run_id)
	var ok: bool = store.save(SNAPSHOT_SCHEMA, raw)
	last_ms = Time.get_ticks_msec() - t0
	if not ok:
		_log("[CHECKPOINT] failed tick=%d" % world.tick)
		return false
	last_hash = world.state_hash()
	last_tick = world.tick
	last_bytes = raw.size()
	_log("[CHECKPOINT] tick=%d hash=%s bytes=%d ms=%d" % [last_tick, last_hash, last_bytes, last_ms])
	return true


## True when any snapshot file exists.
func has_files() -> bool:
	return store.load().status != LoadResult.Status.FRESH


func clear() -> bool:
	return store.remove_all()


## Decodes the snapshot and rebuilds the world. `cfg_factory` is `func(info: SnapshotInfo) -> SimConfig`
## (the run inputs recorded in the header: seed, best wave, frame, wave_mode). Build the mode with
## `SimConfigLoader.apply_mode`: a mode the data lacks falls back to timed, restore then fails and the run is
## banked as ENDED_BY_UPDATE (Q62). A snapshot of a run that was already
## banked (`run_id <= last_banked_run`) or a damaged one is deleted; a `sim_version` or `config_hash`
## mismatch reports ENDED_BY_UPDATE with the header's `data_run` for the caller to bank. Never throws.
func try_resume(cfg_factory: Callable, last_banked_run: int) -> ResumeResult:
	var res: ResumeResult = ResumeResult.new()
	var loaded: LoadResult = store.load()
	if loaded.status == LoadResult.Status.FRESH:
		return res
	if not loaded.has_data():
		_discard("snapshot unreadable (%s)" % LoadResult.Status.keys()[loaded.status])
		res.status = ResumeResult.Status.DISCARDED_DAMAGED
		return res
	var info: SnapshotInfo = SimSnapshot.peek(loaded.raw)
	if info == null:
		_discard("snapshot header invalid")
		res.status = ResumeResult.Status.DISCARDED_DAMAGED
		return res
	res.info = info
	if info.run_id <= last_banked_run:
		_discard("snapshot of banked run %d" % info.run_id)
		res.status = ResumeResult.Status.DISCARDED_BANKED
		return res
	var cfg_var: Variant = cfg_factory.call(info)
	var restored: SimWorld = null
	if info.sim_version == SimVersion.CURRENT and cfg_var is SimConfig:
		var cfg: SimConfig = cfg_var
		restored = SimSnapshot.restore(cfg, loaded.raw)
	if restored == null:
		res.status = ResumeResult.Status.ENDED_BY_UPDATE
		var before: int = BigNum.error_count
		res.data_run = BigNum.parse(info.data_run)
		if BigNum.error_count != before:
			res.data_run = BigNum.zero()
		_discard("snapshot does not match this build (sim_version %d)" % info.sim_version)
		return res
	res.status = ResumeResult.Status.RESUMED
	res.world = restored
	_log("[RESUME] tick=%d hash=%s" % [restored.tick, restored.state_hash()])
	return res


func _discard(why: String) -> void:
	var ok: bool = store.remove_all()
	_log("[CHECKPOINT] discarded: %s (removed=%s)" % [why, str(ok)])


func _log(line: String) -> void:
	log_lines.append_array(PackedStringArray([line]))
	Log.info(line)
