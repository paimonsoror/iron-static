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
