class_name SaveSchema
extends RefCounted
## Profile save document, schema v2 (TECH_ARCHITECTURE 5.1/5.2, M3-04).
##
## Document: {"schema_version": 2, "profile": PlayerProfile.to_dict(), "runs_stats": {}, "config_version": 1}.
## `labs`, `purchase_ledger` and `last_server_time` do not exist yet: their milestone adds them by migration.
## Shape changes need CURRENT + 1, a migration in `migrations()` and a fixture (see MigrationChain).

const CURRENT: int = 2
const CONFIG_VERSION: int = 1
const FIXTURE_DIR: String = "res://tests/fixtures/"


## The real migration table: `table[i]` migrates `i + 1` to `i + 2` (v1 to v2 added the per-mode records).
static func migrations() -> Array[Callable]:
	var table: Array[Callable] = [Callable(MigrateV1ToV2, "apply")]
	return table


static func document_from_profile(p: PlayerProfile) -> Dictionary:
	return {
		"schema_version": CURRENT,
		"profile": p.to_dict(),
		"runs_stats": {},
		"config_version": CONFIG_VERSION,
	}


## Reads a current-schema document. A missing or malformed `profile` gives a fresh-defaults profile with
## the problem in `load_errors`.
static func profile_from_document(d: Dictionary) -> PlayerProfile:
	var raw: Variant = d.get("profile", null)
	if raw is Dictionary:
		var pd: Dictionary = raw
		return PlayerProfile.from_dict(pd)
	var p: PlayerProfile = PlayerProfile.new()
	p.load_errors.append("profile: missing or not a dictionary")
	return p


## Schema version stored in a document (0 when absent or not a number).
static func version_of(d: Dictionary) -> int:
	var v: Variant = d.get("schema_version", 0)
	if v is int:
		var i: int = v
		return i
	if v is float:
		var f: float = v
		return int(f)
	return 0


## Runs the full migration chain from the document's own version to CURRENT (MigrationChain.run result).
static func upgrade(d: Dictionary, from: int) -> Dictionary:
	return MigrationChain.run(d, from, CURRENT, migrations())


## Decoded payload bytes (UTF-8 JSON text) -> document. Empty dictionary when it is not a JSON object.
## Whole-valued floats come back as int, like `SaveCodec.decode_json`.
static func parse_raw(raw: PackedByteArray) -> Dictionary:
	var parser: JSON = JSON.new()  # parse_string logs an engine error on bad input
	if parser.parse(raw.get_string_from_utf8()) != OK:
		return {}
	var parsed: Variant = _normalize(parser.data)
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return d
	return {}


static func raw_from_document(d: Dictionary) -> PackedByteArray:
	return JSON.stringify(d).to_utf8_buffer()


static func _normalize(v: Variant) -> Variant:
	if v is float:
		var f: float = v
		if f == floorf(f) and absf(f) < 9007199254740992.0:
			return int(f)
		return f
	if v is Array:
		var src: Array = v
		var out_a: Array = []
		for item: Variant in src:
			out_a.append(_normalize(item))
		return out_a
	if v is Dictionary:
		var src_d: Dictionary = v
		var out_d: Dictionary = {}
		for k: Variant in src_d:
			out_d[k] = _normalize(src_d[k])
		return out_d
	return v
