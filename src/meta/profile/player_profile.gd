class_name PlayerProfile
extends RefCounted
## Persistent player state and the rules that change it (M3-03). Pure model: no wall time, no RNG, no disk.
## Timestamps and the device id come in as arguments. Serialized by `to_dict` / `from_dict` (schema v1 is
## owned by the save layer; unknown keys survive in `extra`).
##
## Public API (stable, other tracks build on it):
##   static fresh(now_utc, device_id) -> PlayerProfile
##   static from_dict(d) -> PlayerProfile        (validates; problems land in `load_errors`)
##   to_dict() -> Dictionary
##   begin_run() -> int                           (run id; run_counter + 1)
##   bank_run(s: RunSummary) -> bool              (idempotent per run id)
##   best_wave_s1() -> int, best_wave_of(sector) -> int
##   foundry_level(id) -> int, set_foundry_level(id, n)
##   is_frame_unlocked(id) -> bool, unlock_frame(id) -> bool, select_frame(id) -> bool
##   touch(now_utc)                               (sets last_active_utc)
##   has_progress() -> bool                       (runs_total > 0, any Foundry level, or run_counter > 0)

const DEFAULT_FRAME: String = "vanguard"
const FARM_EMA_WEIGHT: float = 0.4
const TICKS_PER_GAME_MINUTE: float = 1800.0  # 30 Hz * 60 s
const SECTOR_1: String = "1"
const KNOWN_KEYS: Array[String] = [
	"data",
	"flux",
	"cipher",
	"merit",
	"foundry",
	"best_wave",
	"runs_total",
	"run_counter",
	"last_banked_run",
	"lifetime_data",
	"farm_rate_1x",
	"settings",
	"frames_unlocked",
	"frame_selected",
	"last_active_utc",
	"device_id",
	"created_utc",
]

var data: BigNum = BigNum.zero()
var flux: int = 0
var cipher: int = 0
var merit: int = 0
## Foundry row id -> level; only rows with level > 0 are stored.
var foundry: Dictionary = {}
## Sector key ("1") -> best death wave.
var best_wave: Dictionary = {}
var runs_total: int = 0
var run_counter: int = 0
var last_banked_run: int = -1
var lifetime_data: BigNum = BigNum.zero()
## EMA (weight 0.4) of data per game-minute at 1x over banked runs (04 economy 2.2).
var farm_rate_1x: float = 0.0
## Opaque here; the shape is owned by PlayerSettings (M3-10).
var settings: Dictionary = {}
var frames_unlocked: Array[String] = [DEFAULT_FRAME]
var frame_selected: String = DEFAULT_FRAME
var last_active_utc: int = 0
var device_id: String = ""
var created_utc: int = 0
## Unknown keys read from a save, written back unchanged.
var extra: Dictionary = {}
## Problems found by `from_dict` (empty for a clean read).
var load_errors: PackedStringArray = PackedStringArray()


static func fresh(now_utc: int, new_device_id: String) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new()
	p.created_utc = now_utc
	p.last_active_utc = now_utc
	p.device_id = new_device_id
	return p


## Starts a run: returns the new run id (the incremented `run_counter`).
func begin_run() -> int:
	run_counter += 1
	return run_counter


## Banks a finished run. Returns false and changes nothing for an old or repeated run id and for runs that
## do not count for progress (debug loads).
func bank_run(s: RunSummary) -> bool:
	if not s.counts_for_progress or s.run_id <= last_banked_run:
		return false
	data = data.add(s.data_run)
	lifetime_data = lifetime_data.add(s.data_run)
	if s.sector == 1:
		best_wave[SECTOR_1] = maxi(best_wave_s1(), s.death_wave)
	runs_total += 1
	_update_farm_rate(s)
	last_banked_run = s.run_id
	return true


func best_wave_s1() -> int:
	return best_wave_of(1)


func best_wave_of(sector: int) -> int:
	var v: Variant = best_wave.get(str(sector), 0)
	if v is int:
		var n: int = v
		return n
	return 0


func foundry_level(id: String) -> int:
	var v: Variant = foundry.get(id, 0)
	if v is int:
		var n: int = v
		return n
	return 0


## Sets a row level (negative clamps to 0; level 0 removes the row). Caps and costs are Foundry rules (M3-06).
func set_foundry_level(id: String, level: int) -> void:
	if level <= 0:
		foundry.erase(id)
	else:
		foundry[id] = level


func touch(now_utc: int) -> void:
	last_active_utc = now_utc


func has_progress() -> bool:
	return runs_total > 0 or run_counter > 0 or not foundry.is_empty()


func is_frame_unlocked(id: String) -> bool:
	return frames_unlocked.has(id)


## Adds a frame to the unlocked set. False when it was already unlocked or the id is empty.
func unlock_frame(id: String) -> bool:
	if id.is_empty() or frames_unlocked.has(id):
		return false
	frames_unlocked.append(id)
	return true


## Selects an unlocked frame. False (nothing changes) when the frame is not unlocked.
func select_frame(id: String) -> bool:
	if not frames_unlocked.has(id):
		return false
	frame_selected = id
	return true


func _update_farm_rate(s: RunSummary) -> void:
	if s.ticks <= 0:
		return
	var minutes: float = float(s.ticks) / TICKS_PER_GAME_MINUTE
	var sample: float = s.data_run.to_float() / minutes
	if is_nan(sample) or is_inf(sample):
		return
	if farm_rate_1x <= 0.0:
		farm_rate_1x = sample
	else:
		farm_rate_1x = FARM_EMA_WEIGHT * sample + (1.0 - FARM_EMA_WEIGHT) * farm_rate_1x


func to_dict() -> Dictionary:
	var d: Dictionary = extra.duplicate(true)
	d["data"] = data.to_text()
	d["flux"] = flux
	d["cipher"] = cipher
	d["merit"] = merit
	d["foundry"] = foundry.duplicate()
	d["best_wave"] = best_wave.duplicate()
	d["runs_total"] = runs_total
	d["run_counter"] = run_counter
	d["last_banked_run"] = last_banked_run
	d["lifetime_data"] = lifetime_data.to_text()
	d["farm_rate_1x"] = farm_rate_1x
	d["settings"] = settings.duplicate(true)
	d["frames_unlocked"] = frames_unlocked.duplicate()
	d["frame_selected"] = frame_selected
	d["last_active_utc"] = last_active_utc
	d["device_id"] = device_id
	d["created_utc"] = created_utc
	return d


## Builds a profile from saved data. Every field is validated; bad ones fall back to defaults and are listed
## in `load_errors`. Missing keys are not errors (older saves).
static func from_dict(d: Dictionary) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.new()
	p.data = _read_big(d, "data", p.load_errors)
	p.lifetime_data = _read_big(d, "lifetime_data", p.load_errors)
	p.flux = _read_int(d, "flux", 0, 0, p.load_errors)
	p.cipher = _read_int(d, "cipher", 0, 0, p.load_errors)
	p.merit = _read_int(d, "merit", 0, 0, p.load_errors)
	p.runs_total = _read_int(d, "runs_total", 0, 0, p.load_errors)
	p.run_counter = _read_int(d, "run_counter", 0, 0, p.load_errors)
	p.last_banked_run = _read_int(d, "last_banked_run", -1, -1, p.load_errors)
	p.last_active_utc = _read_int(d, "last_active_utc", 0, 0, p.load_errors)
	p.created_utc = _read_int(d, "created_utc", 0, 0, p.load_errors)
	p.farm_rate_1x = _read_rate(d, p.load_errors)
	p.device_id = _read_string(d, "device_id", p.load_errors)
	p.foundry = _read_level_map(d, "foundry", true, p.load_errors)
	p.best_wave = _read_level_map(d, "best_wave", false, p.load_errors)
	p.settings = _read_dict(d, "settings", p.load_errors)
	p._read_frames(d)
	for key: Variant in d.keys():
		if not (key is String and KNOWN_KEYS.has(key)):
			p.extra[key] = d[key]
	return p


func _read_frames(d: Dictionary) -> void:
	var list: Array[String] = []
	if d.has("frames_unlocked"):
		var raw: Variant = d["frames_unlocked"]
		if raw is Array:
			var arr: Array = raw
			for item: Variant in arr:
				if item is String:
					var id: String = item
					if not id.is_empty() and not list.has(id):
						list.append(id)
				else:
					load_errors.append("frames_unlocked: non-string entry dropped")
		else:
			load_errors.append("frames_unlocked: not an array")
	if not list.has(DEFAULT_FRAME):
		if d.has("frames_unlocked"):
			load_errors.append("frames_unlocked: %s missing, restored" % DEFAULT_FRAME)
		list.push_front(DEFAULT_FRAME)
	frames_unlocked = list
	var sel: String = DEFAULT_FRAME
	if d.has("frame_selected"):
		var rawsel: Variant = d["frame_selected"]
		var sel_text: String = rawsel if rawsel is String else ""
		if list.has(sel_text):
			sel = sel_text
		else:
			load_errors.append("frame_selected: invalid, using %s" % DEFAULT_FRAME)
	frame_selected = sel


static func _read_big(d: Dictionary, key: String, errors: PackedStringArray) -> BigNum:
	if not d.has(key):
		return BigNum.zero()
	var raw: Variant = d[key]
	if raw is String:
		var before: int = BigNum.error_count
		var text: String = raw
		var v: BigNum = BigNum.parse(text)
		if BigNum.error_count == before:
			return v
	errors.append("%s: invalid BigNum, using 0" % key)
	return BigNum.zero()


static func _read_int(d: Dictionary, key: String, fallback: int, min_value: int, errors: PackedStringArray) -> int:
	if not d.has(key):
		return fallback
	var raw: Variant = d[key]
	if raw is int:
		var i: int = raw
		return maxi(i, min_value)
	if raw is float:
		var f: float = raw
		if not is_nan(f) and not is_inf(f) and f == floorf(f) and absf(f) < 9.0e15:
			return maxi(int(f), min_value)
	errors.append("%s: not an integer, using %d" % [key, fallback])
	return fallback


static func _read_rate(d: Dictionary, errors: PackedStringArray) -> float:
	if not d.has("farm_rate_1x"):
		return 0.0
	var raw: Variant = d["farm_rate_1x"]
	if raw is float or raw is int:
		var f: float = raw
		if not is_nan(f) and not is_inf(f):
			return maxf(f, 0.0)
	errors.append("farm_rate_1x: not a number, using 0")
	return 0.0


static func _read_string(d: Dictionary, key: String, errors: PackedStringArray) -> String:
	if not d.has(key):
		return ""
	var raw: Variant = d[key]
	if raw is String:
		var s: String = raw
		return s
	errors.append("%s: not a string, using empty" % key)
	return ""


static func _read_dict(d: Dictionary, key: String, errors: PackedStringArray) -> Dictionary:
	if not d.has(key):
		return {}
	var raw: Variant = d[key]
	if raw is Dictionary:
		var dd: Dictionary = raw
		return dd.duplicate(true)
	errors.append("%s: not a dictionary, using empty" % key)
	return {}


## String -> int map; entries with non-string keys or non-integer values are dropped (listed), negatives
## clamp to 0, and with `drop_zero` rows at level 0 are not stored.
static func _read_level_map(d: Dictionary, key: String, drop_zero: bool, errors: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	if not d.has(key):
		return out
	var raw: Variant = d[key]
	if not raw is Dictionary:
		errors.append("%s: not a dictionary, using empty" % key)
		return out
	var src: Dictionary = raw
	for k: Variant in src.keys():
		var v: Variant = src[k]
		var level: int = -1
		if v is int:
			var iv: int = v
			level = maxi(iv, 0)
		elif v is float:
			var f: float = v
			if not is_nan(f) and not is_inf(f) and f == floorf(f) and absf(f) < 9.0e15:
				level = maxi(int(f), 0)
		if not k is String or level < 0:
			errors.append("%s: bad entry dropped" % key)
		elif level > 0 or not drop_zero:
			out[k] = level
	return out
