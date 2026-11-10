class_name Palette
extends RefCounted
## Color palette, GDD 07 section 5.2 (hex values exact). One place for every color.
## Red is hostile/danger only, amber is Cinder and information, teal is friendly,
## magenta is enemy projectiles only.

# Background
const VOID := Color("#07090C")
const GRID := Color("#12171D")
const RED_HAZE := Color("#140508")

# HUD
const AMBER := Color("#FFB000")
const AMBER_GLOW := Color("#FFD27A")
const AMBER_DIM := Color("#8A5F00")  # lines, frames, ticks only: 3.5:1 on PANEL is too low for text
## Amber for secondary TEXT (R1-07, I-05): 6.0:1 on PANEL. Use this, not AMBER_DIM, for any label in dim amber.
const AMBER_TEXT := Color("#B88A1E")

# UI
const PANEL := Color("#0D1117")
const TEXT := Color("#F2E6C9")
const TEXT_DIM := Color("#9A8F78")
## Unaffordable / disabled cost text and its frame (R1-07, I-05, 09 Q48): lifted from #5C5546 (2.6:1) to 4.5:1 or more.
const UNAFFORDABLE := Color("#8A8170")

# Player
const CORE := Color("#FFE3A3")
const FRAME := Color("#8FA3B0")
const EMITTER := Color("#FFFFFF")

# Player shots
const LASER_CORE := Color("#FFF1C9")
const LASER_GLOW := Color("#FFB000")
const KINETIC := Color("#C9D1D9")
const ARC := Color("#46E6F0")
const BLAST := Color("#FF8A1F")
const NANO := Color("#B28CFF")

# Friendly
const TEAL := Color("#2EE6D6")

# Enemy
const ENEMY_OUTLINE := Color("#FF2D4B")
const ENEMY_FILL := Color("#2A0A10")
const ENEMY_ELITE := Color("#FF5A3C")
const ENEMY_FIRE := Color("#FF4FD8")
const GHOST := Color(1.0, 0.176, 0.294, 0.15)  # Outline red at 15% alpha

# Foundry level over the soft cap (R1-02): the cost text of a row that costs more than the normal price. Ember orange,
# 7.0:1 on the button plate (PANEL); never red (red is hostile only). R1-07: moved from #FF8A1F (too close to AMBER:
# colour distance 11 under deuteranopia) to #FF7A2E (18).
const OVER_LIMIT := Color("#FF7A2E")

# Warning
const WARNING := Color("#FFC21A")
const CRITICAL := Color("#FF3B30")

# Currencies
const SCRAP := Color("#D6B36A")
const DATA := Color("#5BC8FF")
const FLUX := Color("#2EE6D6")
const CIPHER := Color("#E0B0FF")
const MERIT := Color("#FFD84D")

## Enemy interior alpha (GDD 07 section 5.1: filled at 80%).
const ENEMY_FILL_ALPHA: float = 0.8

# Material ramps, art bible section 3.2 (V1-02). Sprites bake these values; code-drawn parts and tests use them.
# Charred plate base (the former CHAR constant) for code-drawn scorch marks
const CHARRED_BASE := Color("#3A2A22")
const EMBER_EDGE := Color("#FF8A1F")
const SPARK := Color("#FFD27A")
# Cinder armor plates (gunmetal / ceramic, V1-GATE decision 4).
# They replaced the tan SKIN ramp (removed in V1-11).
const ARMOR_SHADOW := Color("#38434B")
const ARMOR_BASE := Color("#6B7882")
const ARMOR_LIGHT := Color("#9AA8B3")
const ARMOR_HIGHLIGHT := Color("#DCE6EC")
# Cinder frame (gunmetal; FRAME is the light step)
const FRAME_DEEP := Color("#12181D")
const FRAME_SHADOW := Color("#2B343B")
const FRAME_BASE := Color("#56656F")
const FRAME_HIGHLIGHT := Color("#D4E0E8")
const FRAME_HOT := Color("#FFF1C9")
const CORE_CRACK := Color("#FF3B30")
# Enemy hull (ENEMY_FILL is the base) and rim/vent emissives
const HULL_SHADOW := Color("#12060A")
const HULL_LIGHT := Color("#4A1220")
const HULL_HIGHLIGHT := Color("#7A1E30")
const ENEMY_RIM_HOT := Color("#FF6B7E")
const ENEMY_VENT := Color("#FFC2CC")
# Enemy accent / bolt ramp (ENEMY_FIRE is the base)
const ENEMY_FIRE_SHADOW := Color("#8A1F78")
const ENEMY_FIRE_LIGHT := Color("#FF9AE8")
const ENEMY_FIRE_HIGHLIGHT := Color("#FFE0F8")
# Boss hull (trim is ENEMY_ELITE, reactor CRITICAL to CORE)
const BOSS_SHADOW := Color("#1A0509")
const BOSS_BASE := Color("#3A0F18")
const BOSS_LIGHT := Color("#6A1C2A")
const BOSS_HIGHLIGHT := Color("#9A2E3E")
# Floor (VOID, GRID are the shadow and light steps) and UI plates (PANEL is the base)
const FLOOR_BASE := Color("#0B0E13")
const FLOOR_HIGHLIGHT := Color("#1B222B")
const PLATE_SHADOW := Color("#080B10")
const PLATE_LIGHT := Color("#151B24")
const PLATE_HIGHLIGHT := Color("#222B38")
# Per-type enemy accent colors (V1-GATE decision 3): rim, vents and emissives carry the accent, hulls stay dark
const ACCENT_SKITTER := Color("#FF2D4B")
const ACCENT_DART := Color("#FF4FD8")
const ACCENT_WALKER := Color("#FF7A1A")
const ACCENT_LANCER := Color("#A35CFF")
const ACCENT_BOSS := Color("#FF1F3D")

# --- Accessibility palettes (M4-24) ---------------------------------------------------------------------------
const PALETTES_PATH: String = "res://assets/art/palettes.csv"
const MODES: Array[String] = ["off", "deuteranopia", "protanopia", "tritanopia"]
const HIGH_CONTRAST: String = "high_contrast"

## The set the HUD, Cinder ring and integrity bars read; changed only by `set_active` (VisualSettings does).
static var active: PaletteSet = null
static var active_contrast: bool = false
static var _sets: Dictionary = {}


## The palette of a colorblind mode ("off" and unknown ids give the normal one) or of "high_contrast".
## Loaded once from `assets/art/palettes.csv`; the returned set is shared, never modify it.
static func for_mode(id: String) -> PaletteSet:
	_ensure_loaded()
	var key: String = id if _sets.has(id) else "off"
	var found: PaletteSet = _sets[key]
	return found


## Makes `mode` the active gameplay palette and records the high-contrast flag (no allocation after the first load).
static func set_active(mode: String, contrast: bool) -> void:
	active = for_mode(mode)
	active_contrast = contrast


## The active gameplay palette (the normal one before anything was set).
static func current() -> PaletteSet:
	if active == null:
		active = for_mode("off")
	return active


static func _ensure_loaded() -> void:
	if not _sets.is_empty():
		return
	for id: String in MODES + [HIGH_CONTRAST]:
		var fresh := PaletteSet.new()
		fresh.mode = id
		_sets[id] = fresh
	var f: FileAccess = FileAccess.open(PALETTES_PATH, FileAccess.READ)
	if f == null:
		push_error("Palette: cannot read %s" % PALETTES_PATH)
	else:
		for line: String in f.get_as_text().split("\n"):
			_read_line(line.strip_edges())
	for id: String in _sets:
		var s: PaletteSet = _sets[id]
		s.finish()


static func _read_line(line: String) -> void:
	if line.is_empty() or line.begins_with("#") or line.begins_with("mode,"):
		return
	var cols: PackedStringArray = line.split(",")
	if cols.size() < 3 or not _sets.has(cols[0]):
		push_error("Palette: bad palettes.csv row '%s'" % line)
		return
	var s: PaletteSet = _sets[cols[0]]
	if not s.set_role(cols[1], cols[2]):
		push_error("Palette: bad role or value in row '%s'" % line)
