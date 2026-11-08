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
const AMBER_DIM := Color("#8A5F00")

# UI
const PANEL := Color("#0D1117")
const TEXT := Color("#F2E6C9")
const TEXT_DIM := Color("#9A8F78")
const UNAFFORDABLE := Color("#5C5546")

# Player
const CORE := Color("#FFE3A3")
const FRAME := Color("#8FA3B0")
const SKIN := Color("#D9A383")
const CHAR := Color("#3A2A22")
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
# Cinder skin plates (base and light/shadow ramp; SKIN is the base) and charred plates (CHAR is the base)
const SKIN_SHADOW := Color("#8A5A44")
const SKIN_LIGHT := Color("#F0C4A0")
const SKIN_HIGHLIGHT := Color("#FFE6CC")
const CHAR_SHADOW := Color("#1F1612")
const CHAR_LIGHT := Color("#5A4034")
const CHAR_HIGHLIGHT := Color("#7A5A48")
const EMBER_EDGE := Color("#FF8A1F")
const SPARK := Color("#FFD27A")
# Cinder frame (gunmetal; FRAME is the light step)
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
