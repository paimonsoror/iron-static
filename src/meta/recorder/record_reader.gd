class_name RecordReader
extends RefCounted
## Tolerant reads of the Service Record in `profile.extra` (`ServiceRecord`): JSON turns ints into floats and a hand
## edited or damaged save can hold anything, so every getter falls back to 0 / empty. Read-only: never creates the
## record. Used by the Service Record screen and by `ServiceRecord` itself.


static func int_of(d: Dictionary, key: String) -> int:
	var v: Variant = d.get(key, 0)
	if v is int:
		var i: int = v
		return maxi(i, 0)
	if v is float:
		var f: float = v
		if not is_nan(f) and not is_inf(f):
			return maxi(int(f), 0)
	return 0


static func big_of(d: Dictionary, key: String) -> BigNum:
	var v: Variant = d.get(key, null)
	if v is String:
		var text: String = v
		var before: int = BigNum.error_count
		var n: BigNum = BigNum.parse(text)
		if BigNum.error_count == before:
			return n
	return BigNum.zero()


## The record dictionary (a read-only view: do not write to it); empty when there is none.
static func record(profile: PlayerProfile) -> Dictionary:
	var raw: Variant = profile.extra.get(ServiceRecord.KEY, null)
	if raw is Dictionary:
		var rec: Dictionary = raw
		if int_of(rec, "v") == ServiceRecord.VERSION:
			return rec
	return {}


static func total(profile: PlayerProfile, key: String) -> int:
	return int_of(record(profile), key)


static func total_big(profile: PlayerProfile, key: String) -> BigNum:
	return big_of(record(profile), key)


## Deployments banked since tracking began in wave mode `mode`.
static func runs_of_mode(profile: PlayerProfile, mode: String) -> int:
	return int_of(child(record(profile), "runs"), mode)


## Deployments banked before tracking began, of an unknown mode (an older save).
static func runs_before(profile: PlayerProfile) -> int:
	return total(profile, "runs_pre")


static func runs_all(profile: PlayerProfile) -> int:
	var n: int = runs_before(profile)
	var runs: Dictionary = child(record(profile), "runs")
	for mode: Variant in runs.keys():
		n += int_of(runs, str(mode))
	return n


static func kills_of(profile: PlayerProfile, enemy_id: String) -> int:
	return int_of(child(record(profile), "kills"), enemy_id)


## Total kills over every enemy id in the record (including ids this build no longer has).
static func kills_all(profile: PlayerProfile) -> int:
	var kills: Dictionary = child(record(profile), "kills")
	var n: int = 0
	for id: Variant in kills.keys():
		n += int_of(kills, str(id))
	return n


static func frame_runs(profile: PlayerProfile, frame_id: String) -> int:
	return int_of(child(child(record(profile), "frames"), frame_id), "r")


static func frame_best(profile: PlayerProfile, frame_id: String) -> int:
	return int_of(child(child(record(profile), "frames"), frame_id), "b")


## `since` (unix seconds, 0 = unknown).
static func since(profile: PlayerProfile) -> int:
	return total(profile, "since")


## True when the record was started from an older save (some totals begin at the seeding date).
static func seeded(profile: PlayerProfile) -> bool:
	return total(profile, "seeded") > 0


## Child dictionary `key` of `d`, or an empty one.
static func child(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, null)
	if v is Dictionary:
		var out: Dictionary = v
		return out
	return {}
