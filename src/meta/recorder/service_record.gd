class_name ServiceRecord
extends RefCounted
## Lifetime statistics of the profile ("SERVICE RECORD"), kept in the profile `extra` dictionary under `KEY` like the
## flight recorder (no save schema bump, unknown keys survive, every read tolerates JSON floats and bad values). The
## record dies with the profile: RESET PROFILE builds a fresh profile and `ensure` starts a new record. A run is
## committed exactly once, when it is banked (`SaveService.bank_run`, idempotent per run id), from `RunTotals`; play
## time arrives in whole seconds from `PlayTimer`. Nothing leaves the device. Time enters only through `ClockSource`
## (the "tracked since" stamp). Reading is `RecordReader`; seeding an older save is `RecordSeed`.
##
## Shape: `{"v": 1, "since": utc, "seeded": 0|1, "play_s": n, "deploy_ticks": n, "longest_ticks": n,
## "runs": {"timed": n, "purge": n}, "runs_pre": n, "waves": n, "bosses": n, "upgrades": n, "patches": n,
## "kills": {"skitter": n}, "damage": "1.5e9", "shots": n, "crits": n, "hit_max": n, "hull": n,
## "scrap_in": "text", "scrap_out": "text", "gaps": n, "frames": {"vanguard": {"r": n, "b": best}}}`

const KEY: String = "record"
const VERSION: int = 1


## Makes sure the profile has a current record: an absent or unreadable one is built (seeded from what an older save
## already knows, see `RecordSeed`). Call after every load and after a profile reset.
static func ensure(profile: PlayerProfile, clock: ClockSource) -> void:
	var raw: Variant = profile.extra.get(KEY, null)
	if raw is Dictionary:
		var rec: Dictionary = raw
		if RecordReader.int_of(rec, "v") == VERSION:
			return
	profile.extra[KEY] = RecordSeed.build(profile, clock)


## Foreground seconds (from `PlayTimer`).
static func note_seconds(profile: PlayerProfile, seconds: int) -> void:
	if seconds <= 0:
		return
	var rec: Dictionary = live(profile)
	rec["play_s"] = RecordReader.int_of(rec, "play_s") + seconds


## Adds one banked run. Call once per run id (the caller is `SaveService.bank_run`, which banks each id once).
static func commit_run(profile: PlayerProfile, t: RunTotals) -> void:
	var rec: Dictionary = live(profile)
	var runs: Dictionary = _sub(rec, "runs")
	runs[t.mode] = RecordReader.int_of(runs, t.mode) + 1
	_add(rec, "deploy_ticks", t.ticks)
	rec["longest_ticks"] = maxi(RecordReader.int_of(rec, "longest_ticks"), t.ticks)
	_add(rec, "waves", t.waves_cleared)
	if not t.frame_id.is_empty():
		var frames: Dictionary = _sub(rec, "frames")
		var f: Dictionary = _sub(frames, t.frame_id)
		f["r"] = RecordReader.int_of(f, "r") + 1
		f["b"] = maxi(RecordReader.int_of(f, "b"), t.wave)
	if t.detail == RunTotals.Detail.SUMMARY:
		_add(rec, "gaps", 1)
		return
	var kills: Dictionary = _sub(rec, "kills")
	for id: Variant in t.kills.keys():
		var key: String = str(id)
		var n: int = t.kills[id]
		kills[key] = RecordReader.int_of(kills, key) + n
	_add(rec, "bosses", t.bosses)
	_add(rec, "upgrades", t.upgrades)
	_add(rec, "patches", t.patches)
	_add_big(rec, "damage", t.damage)
	if t.detail != RunTotals.Detail.FULL:
		_add(rec, "gaps", 1)
		return
	_add(rec, "shots", t.shots)
	_add(rec, "crits", t.crits)
	rec["hit_max"] = maxi(RecordReader.int_of(rec, "hit_max"), t.hit_max)
	_add(rec, "hull", t.hull)
	_add_big(rec, "scrap_in", t.scrap_in)
	_add_big(rec, "scrap_out", t.scrap_out)


## The live record dictionary inside `profile.extra` (created, with an unknown start, when missing or damaged).
static func live(profile: PlayerProfile) -> Dictionary:
	var raw: Variant = profile.extra.get(KEY, null)
	if raw is Dictionary:
		var rec: Dictionary = raw
		if RecordReader.int_of(rec, "v") == VERSION:
			return rec
	var fresh: Dictionary = {"v": VERSION, "since": 0}
	profile.extra[KEY] = fresh
	return fresh


static func _add(d: Dictionary, key: String, n: int) -> void:
	d[key] = RecordReader.int_of(d, key) + maxi(n, 0)


static func _add_big(d: Dictionary, key: String, n: BigNum) -> void:
	d[key] = RecordReader.big_of(d, key).add(n).to_text()


## The child dictionary `key` of `d` (created or repaired when missing or not a dictionary).
static func _sub(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, null)
	if v is Dictionary:
		var out: Dictionary = v
		return out
	var fresh: Dictionary = {}
	d[key] = fresh
	return fresh
