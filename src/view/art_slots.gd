class_name ArtSlots
extends RefCounted
## Data-driven art slots: reads `res://assets/art/slots.csv` (ArtSlot rows) and hands out sheet rectangles, pivots,
## frame data and textures, so swapping art = replacing the SVG (or PNG with the same name) and editing the table.
## Export: `slots.csv.import` uses the `keep` importer, so the CSV ships as is (no translation import) and is read
## with FileAccess like any res:// file. A missing slot or file never crashes: `slot()` returns an invalid ArtSlot
## and `texture()` a 1x1 magenta placeholder, both logged through `push_error` (switch off with `log_errors`).

const CSV_PATH: String = "res://assets/art/slots.csv"
const SRC_DIR: String = "res://assets/art/src/"

## Tests and tools set this to false to exercise the failure paths without ERROR lines in the output.
static var log_errors: bool = true
## Last problem seen by the loader or the texture lookup ("" = none), and how many were counted.
static var last_error: String = ""
static var error_count: int = 0

static var _slots: Dictionary = {}
static var _order: PackedStringArray = PackedStringArray()
static var _loaded: bool = false
static var _textures: Dictionary = {}
static var _atlases: Dictionary = {}
static var _placeholder: Texture2D = null


## Looks up a slot. Unknown ids log an error and return an ArtSlot with `valid == false` (never null).
static func slot(slot_id: String) -> ArtSlot:
	_ensure()
	if _slots.has(slot_id):
		var found: ArtSlot = _slots[slot_id]
		return found
	_fail("unknown art slot '%s'" % slot_id)
	var missing: ArtSlot = ArtSlot.new()
	missing.id = slot_id
	return missing


static func has(slot_id: String) -> bool:
	_ensure()
	return _slots.has(slot_id)


## All slot ids in table order.
static func ids() -> PackedStringArray:
	_ensure()
	return _order


## Ids of one family (`enemy|cinder|fx|ui|floor|icon`) in table order.
static func ids_of_family(family: String) -> PackedStringArray:
	_ensure()
	var out: PackedStringArray = PackedStringArray()
	for sid: String in _order:
		var s: ArtSlot = _slots[sid]
		if s.family == family:
			out.append(sid)
	return out


## Frame rect in texels of the sheet.
static func frame_rect(art: ArtSlot, frame: int) -> Rect2:
	return art.frame_rect(frame)


## Frame rect as 0..1 UV of the sheet (feeds shaders and MultiMesh custom data).
static func frames_uv(art: ArtSlot, frame: int) -> Rect2:
	return art.frames_uv(frame)


## The paired glow slot (additive, own sheet), or an invalid slot (no error logged) when the slot has none.
static func glow_of(slot_id: String) -> ArtSlot:
	var base: ArtSlot = slot(slot_id)
	if base.glow_slot.is_empty():
		return ArtSlot.new()
	return slot(base.glow_slot)


## Whole-sheet texture of the slot's file; a magenta 1x1 placeholder (and an error) when the file is missing.
static func texture(slot_id: String) -> Texture2D:
	var art: ArtSlot = slot(slot_id)
	if not art.valid or art.is_reserved():
		if art.valid:
			_fail("art slot '%s' is reserved (no file yet)" % slot_id)
		return placeholder()
	return _sheet_texture(art.file)


## One frame as an AtlasTexture of the sheet (cached per slot and frame).
static func atlas(slot_id: String, frame: int = 0) -> AtlasTexture:
	var art: ArtSlot = slot(slot_id)
	var key: String = "%s#%d" % [slot_id, clampi(frame, 0, maxi(art.frames - 1, 0))]
	if _atlases.has(key):
		var cached: AtlasTexture = _atlases[key]
		return cached
	var at: AtlasTexture = AtlasTexture.new()
	at.atlas = texture(slot_id)
	at.region = art.frame_rect(frame) if art.valid else Rect2(0, 0, 1, 1)
	_atlases[key] = at
	return at


## 1x1 magenta texture used when a slot file is missing (a missing art swap must be visible, not fatal).
static func placeholder() -> Texture2D:
	if _placeholder == null:
		var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.0, 1.0, 1.0))
		_placeholder = ImageTexture.create_from_image(img)
	return _placeholder


## Replaces the table with `text` (CSV in the slots.csv schema). Returns the number of slots loaded.
static func load_text(text: String, source: String = "<text>") -> int:
	_slots = {}
	_order = PackedStringArray()
	_textures = {}
	_atlases = {}
	_loaded = true
	var table: CsvTable = CsvTable.parse(text, source)
	if not table.error.is_empty():
		_fail(table.error)
		return 0
	for r: int in range(table.rows.size()):
		_add_row(table, r)
	return _order.size()


## Forgets everything and reloads `CSV_PATH` on the next access.
static func reset() -> void:
	_slots = {}
	_order = PackedStringArray()
	_textures = {}
	_atlases = {}
	_loaded = false
	last_error = ""
	error_count = 0


static func _ensure() -> void:
	if _loaded:
		return
	var table: CsvTable = CsvTable.load_file(CSV_PATH)
	_loaded = true
	if not table.error.is_empty():
		_fail(table.error)
		return
	for r: int in range(table.rows.size()):
		_add_row(table, r)


static func _add_row(table: CsvTable, r: int) -> void:
	var sid: String = table.get_value(r, "slot")
	if sid.is_empty() or _slots.has(sid):
		_fail("%s: row %d has an empty or duplicate slot id '%s'" % [table.path, r + 1, sid])
		return
	var s: ArtSlot = ArtSlot.new()
	s.id = sid
	s.file = table.get_value(r, "file")
	s.glow_file = table.get_value(r, "glow_file")
	s.glow_slot = table.get_value(r, "glow_slot")
	s.sheet_size = Vector2i(_i(table, r, "sheet_w"), _i(table, r, "sheet_h"))
	s.cell_pos = Vector2i(_i(table, r, "cell_x"), _i(table, r, "cell_y"))
	s.cell_size = Vector2i(_i(table, r, "cell_w"), _i(table, r, "cell_h"))
	s.frames = maxi(_i(table, r, "frames"), 1)
	s.pivot = Vector2(_f(table, r, "pivot_x"), _f(table, r, "pivot_y"))
	s.fps = _f(table, r, "fps")
	s.body_radius_px = _f(table, r, "body_radius_px")
	s.texel_per_px = _f(table, r, "texel_per_px")
	var vs: String = table.get_value(r, "visual_scale")
	s.visual_scale = vs.to_float() if not vs.is_empty() else 1.0
	s.aspect = _f(table, r, "aspect")
	s.margin = _i(table, r, "margin")
	var mc: String = table.get_value(r, "min_coverage")
	s.min_coverage = mc.to_float() if not mc.is_empty() else 3.0
	s.additive = table.get_value(r, "blend") == "add"
	s.family = table.get_value(r, "family")
	s.status = table.get_value(r, "status")
	s.notes = table.get_value(r, "notes")
	s.valid = true
	_slots[sid] = s
	_order.append(sid)


static func _i(table: CsvTable, r: int, col: String) -> int:
	return table.get_value(r, col).to_int()


static func _f(table: CsvTable, r: int, col: String) -> float:
	return table.get_value(r, col).to_float()


static func _sheet_texture(file: String) -> Texture2D:
	if _textures.has(file):
		var cached: Texture2D = _textures[file]
		return cached
	var path: String = SRC_DIR + file
	if not ResourceLoader.exists(path):
		_fail("art file missing: " + path)
		return placeholder()
	var loaded: Texture2D = load(path) as Texture2D
	if loaded == null:
		_fail("art file is not a texture: " + path)
		return placeholder()
	_textures[file] = loaded
	return loaded


static func _fail(message: String) -> void:
	last_error = message
	error_count += 1
	if log_errors:
		push_error("ArtSlots: " + message)
