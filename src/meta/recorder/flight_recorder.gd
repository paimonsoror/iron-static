class_name FlightRecorder
extends RefCounted
## Local flight recorder (R1-08, review O-02): a ring of per-day play counters in the profile `extra` dictionary under
## `KEY` (no save schema bump, unknown keys already survive). Per UTC day: sessions, runs per wave mode, seconds played,
## best wave, deepest screen reached and the last screen seen (the one before quit). Days older than `KEEP_DAYS` are
## dropped whenever a day is touched. Nothing here leaves the device; `PlaySummary` turns it into text the player may
## copy and paste. Time enters only through the injected `ClockSource`. JSON turns ints into floats on load, so every
## read goes through `_int`.
##
## Shape: `{"v": 1, "days": {"2026-11-10": {"s": 2, "r": {"timed": 4, "purge": 1}, "sec": 1860, "b": 38,
## "d": "foundry", "l": "results"}}}`

const KEY: String = "flight"
const VERSION: int = 1
const KEEP_DAYS: int = 30
const SECONDS_PER_DAY: int = 86400
## Funnel depth of a screen name (`AppFlow.Screen` lower-cased): the deepest one reached wins the day's "d".
const SCREEN_RANK: Dictionary[String, int] = {
	"save_problem": 0,
	"title": 1,
	"cold_open": 2,
	"frame_bay": 2,
	"home": 3,
	"settings": 3,
	"foundry": 4,
	"battle": 5,
	"results": 6,
}


## `YYYY-MM-DD` of a UTC unix time (civil date from days since 1970, integer math; no engine time calls).
static func day_key(utc: int) -> String:
	var z: int = _fdiv(utc, SECONDS_PER_DAY) + 719468
	var era: int = _fdiv(z, 146097)
	var doe: int = z - era * 146097
	var yoe: int = _fdiv(doe - _fdiv(doe, 1460) + _fdiv(doe, 36524) - _fdiv(doe, 146096), 365)
	var y: int = yoe + era * 400
	var doy: int = doe - (365 * yoe + _fdiv(yoe, 4) - _fdiv(yoe, 100))
	var mp: int = _fdiv(5 * doy + 2, 153)
	var d: int = doy - _fdiv(153 * mp + 2, 5) + 1
	var m: int = mp + 3 if mp < 10 else mp - 9
	if m <= 2:
		y += 1
	return "%04d-%02d-%02d" % [y, m, d]


static func note_session(profile: PlayerProfile, clock: ClockSource) -> void:
	var day: Dictionary = _today(profile, clock)
	day["s"] = _int(day, "s") + 1


## One finished or aborted run of `mode` that reached `wave`.
static func note_run(profile: PlayerProfile, clock: ClockSource, mode: String, wave: int) -> void:
	var day: Dictionary = _today(profile, clock)
	var runs: Dictionary = _dict(day, "r")
	runs[mode] = _int(runs, mode) + 1
	day["r"] = runs
	day["b"] = maxi(_int(day, "b"), wave)


static func note_seconds(profile: PlayerProfile, clock: ClockSource, seconds: int) -> void:
	if seconds <= 0:
		return
	var day: Dictionary = _today(profile, clock)
	day["sec"] = _int(day, "sec") + seconds


## The player is now on `screen` (name of an `AppFlow.Screen`, lower case).
static func note_screen(profile: PlayerProfile, clock: ClockSource, screen: String) -> void:
	var day: Dictionary = _today(profile, clock)
	day["l"] = screen
	var deepest: String = str(day.get("d", ""))
	if SCREEN_RANK.get(screen, -1) > SCREEN_RANK.get(deepest, -1):
		day["d"] = screen


## The recorded days as `{key: Dictionary}`, a copy; empty when nothing was recorded.
static func days(profile: PlayerProfile) -> Dictionary:
	var raw: Variant = profile.extra.get(KEY, null)
	if raw is Dictionary:
		var root: Dictionary = raw
		var d: Variant = root.get("days", null)
		if d is Dictionary:
			var src: Dictionary = d
			return src.duplicate(true)
	return {}


static func int_of(day: Dictionary, key: String) -> int:
	return _int(day, key)


## Today's record (created on first use), after dropping days outside the ring.
static func _today(profile: PlayerProfile, clock: ClockSource) -> Dictionary:
	var utc: int = clock.now_utc()
	var all: Dictionary = _days_ref(profile)
	var key: String = day_key(utc)
	var cutoff: String = day_key(utc - (KEEP_DAYS - 1) * SECONDS_PER_DAY)
	for k: Variant in all.keys():
		if str(k) < cutoff:
			@warning_ignore("return_value_discarded")
			all.erase(k)
	if not all.has(key) or not (all[key] is Dictionary):
		all[key] = {}
	var day: Dictionary = all[key]
	return day


## The live `days` dictionary inside `profile.extra` (created or repaired when missing or damaged).
static func _days_ref(profile: PlayerProfile) -> Dictionary:
	var raw: Variant = profile.extra.get(KEY, null)
	var root: Dictionary = {}
	if raw is Dictionary:
		root = raw
	if _int(root, "v") != VERSION:
		root = {"v": VERSION, "days": {}}
	if not (root.get("days", null) is Dictionary):
		root["days"] = {}
	profile.extra[KEY] = root
	var d: Dictionary = root["days"]
	return d


static func _fdiv(a: int, b: int) -> int:
	return floori(float(a) / float(b))


static func _int(d: Dictionary, key: String) -> int:
	var v: Variant = d.get(key, 0)
	if v is int:
		var i: int = v
		return i
	if v is float:
		var f: float = v
		return int(f)
	return 0


static func _dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, null)
	if v is Dictionary:
		var out: Dictionary = v
		return out
	return {}
