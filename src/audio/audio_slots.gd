class_name AudioSlots
extends RefCounted
## Data-driven audio slots (mirror of ArtSlots): reads `res://assets/audio/slots.csv` through CsvTable.
## `slots.csv.import` uses the `keep` importer (not a translation); audio files live in a normal, importable
## folder (never `.gdignore`d). A missing slot or file never crashes: `slot()` returns an invalid AudioSlot and
## `stream()` returns null, both logged through push_error unless `log_errors` is false (tests).

const CSV_PATH: String = "res://assets/audio/slots.csv"
const AUDIO_DIR: String = "res://assets/audio/"

static var log_errors: bool = true
static var last_error: String = ""
static var error_count: int = 0

static var _slots: Dictionary = {}
static var _order: PackedStringArray = PackedStringArray()
static var _loaded: bool = false
static var _streams: Dictionary = {}


static func slot(slot_id: String) -> AudioSlot:
	_ensure()
	if _slots.has(slot_id):
		var found: AudioSlot = _slots[slot_id]
		return found
	_fail("unknown audio slot '%s'" % slot_id)
	var missing: AudioSlot = AudioSlot.new()
	missing.id = slot_id
	return missing


static func has(slot_id: String) -> bool:
	_ensure()
	return _slots.has(slot_id)


static func ids() -> PackedStringArray:
	_ensure()
	return _order


## Loaded stream of a slot (cached), or null when the slot or file is missing or reserved.
static func stream(slot_id: String) -> AudioStream:
	var s: AudioSlot = slot(slot_id)
	if not s.valid or s.is_reserved():
		if s.valid:
			_fail("audio slot '%s' is reserved (no file yet)" % slot_id)
		return null
	if _streams.has(s.file):
		var cached: AudioStream = _streams[s.file]
		return cached
	var path: String = AUDIO_DIR + s.file
	if not ResourceLoader.exists(path):
		_fail("audio file missing: " + path)
		return null
	var loaded: AudioStream = load(path) as AudioStream
	if loaded == null:
		_fail("audio file is not a stream: " + path)
		return null
	_streams[s.file] = loaded
	return loaded


## Replaces the table with CSV `text` (slots.csv schema). Returns the number of slots loaded.
static func load_text(text: String, source: String = "<text>") -> int:
	reset()
	_loaded = true
	var table: CsvTable = CsvTable.parse(text, source)
	if not table.error.is_empty():
		_fail(table.error)
		return 0
	for r: int in range(table.rows.size()):
		_add_row(table, r)
	return _order.size()


## Forgets the loaded streams (slot rows stay); called on shutdown so statics hold no resources at exit.
static func release_streams() -> void:
	_streams = {}


static func reset() -> void:
	_slots = {}
	_order = PackedStringArray()
	_streams = {}
	_loaded = false
	last_error = ""
	error_count = 0


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var table: CsvTable = CsvTable.load_file(CSV_PATH)
	if not table.error.is_empty():
		_fail(table.error)
		return
	for r: int in range(table.rows.size()):
		_add_row(table, r)


static func _add_row(table: CsvTable, r: int) -> void:
	var sid: String = table.get_value(r, "id")
	if sid.is_empty() or _slots.has(sid):
		_fail("%s: row %d has an empty or duplicate id '%s'" % [table.path, r + 1, sid])
		return
	var s: AudioSlot = AudioSlot.new()
	s.id = sid
	s.file = table.get_value(r, "file")
	s.bus = table.get_value(r, "bus")
	s.volume_db = table.get_value(r, "volume_db").to_float()
	s.pitch_var = clampf(table.get_value(r, "pitch_var").to_float(), 0.0, 0.5)
	s.voice_cap = maxi(table.get_value(r, "voice_cap").to_int(), 1)
	s.cooldown_ms = maxi(table.get_value(r, "cooldown_ms").to_int(), 0)
	s.valid = true
	_slots[sid] = s
	_order.append(sid)


static func _fail(message: String) -> void:
	last_error = message
	error_count += 1
	if log_errors:
		push_error("AudioSlots: " + message)
