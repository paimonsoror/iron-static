class_name SaveStore
extends RefCounted
## Crash-safe store for one signed blob (M3-02): `<name>.sav` live, `<name>.bak` previous good,
## `<name>.tmp` in flight. Never wipes: a damaged or too-new file is only ever replaced by a
## verified newer write, or renamed to `<name>.corrupt*` by an explicit `quarantine()`.
## All file access goes through the injected `SaveFs`. (impl) the constructor also takes the store
## `name` (the spec leaves it implicit), and `load()` may omit `max_schema` to use the constructor's.

const ANY_SCHEMA: int = 0xFFFF

var _fs: SaveFs
var _name: String
var _magic: String
var _max_schema: int


func _init(fs: SaveFs, store_name: String, magic: String, max_schema: int) -> void:
	_fs = fs
	_name = store_name
	_magic = magic
	_max_schema = max_schema


func live_path() -> String:
	return _name + ".sav"


func bak_path() -> String:
	return _name + ".bak"


func tmp_path() -> String:
	return _name + ".tmp"


## Atomic save: tmp, read-back verify, live -> bak (only if live is valid), tmp -> live.
## False leaves the previous good state loadable.
func save(schema: int, raw: PackedByteArray) -> bool:
	var enc: PackedByteArray = SaveCodec.encode(_magic, schema, raw)
	if enc.is_empty():
		return false
	if not _fs.write(tmp_path(), enc):
		return false
	var check: DecodeResult = SaveCodec.decode(_magic, _fs.read(tmp_path()), maxi(_max_schema, schema))
	if check.status != DecodeResult.Status.OK or check.raw != raw:
		_fs.remove(tmp_path())  # best effort; an invalid tmp is ignored by load anyway
		return false
	if _fs.exists(live_path()):
		# (impl) a too-new live file is validly signed, so it is a good backup; only damage is skipped.
		var live: DecodeResult = SaveCodec.decode(_magic, _fs.read(live_path()), ANY_SCHEMA)
		if live.status == DecodeResult.Status.OK:
			if not _fs.rename(live_path(), bak_path()):
				return false
	return _fs.rename(tmp_path(), live_path())


## Load order: live, then bak, then a valid tmp (crash between the two renames).
func load(max_schema: int = -1) -> LoadResult:
	var limit: int = _max_schema if max_schema < 0 else max_schema
	var res: LoadResult = LoadResult.new()
	var any_file: bool = false
	var cands: Array[String] = [live_path(), bak_path(), tmp_path()]
	var sources: Array[String] = ["live", "bak", "tmp"]
	for i: int in cands.size():
		if not _fs.exists(cands[i]):
			continue
		any_file = true
		var d: DecodeResult = SaveCodec.decode(_magic, _fs.read(cands[i]), limit)
		if d.status == DecodeResult.Status.OK:
			res.status = LoadResult.Status.OK if i == 0 else LoadResult.Status.RECOVERED
			res.source = sources[i]
			res.schema = d.schema
			res.raw = d.raw
			return res
		if d.status == DecodeResult.Status.TOO_NEW:
			# (impl) stop at the first too-new file: falling back to an older backup would let a
			# downgrade overwrite newer data.
			res.status = LoadResult.Status.TOO_NEW
			res.found_schema = d.schema
			return res
	res.status = LoadResult.Status.CORRUPT if any_file else LoadResult.Status.FRESH
	return res


## Rename every existing live/bak/tmp file to `<name>.corrupt`, `.corrupt.1`, ... (never overwriting).
## Explicit player action only. True when every rename worked.
func quarantine() -> bool:
	var ok: bool = true
	for p: String in [live_path(), bak_path(), tmp_path()]:
		if not _fs.exists(p):
			continue
		var target: String = _name + ".corrupt"
		var k: int = 0
		while _fs.exists(target):
			k += 1
			target = _name + ".corrupt." + str(k)
		if not _fs.rename(p, target):
			ok = false
	return ok


## Delete all three files (run snapshot at run end). True when none is left.
func remove_all() -> bool:
	var ok: bool = true
	for p: String in [live_path(), bak_path(), tmp_path()]:
		if _fs.exists(p) and not _fs.remove(p):
			ok = false
	return ok
