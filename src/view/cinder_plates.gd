class_name CinderPlates
extends RefCounted
## Pure layout of the hull armor plates (VT-3, docs/design/12 section 4.2): which cells are drawn at a plate tier and
## at which angles. The cells are authored pointing up with the pivot on Cinder's center and drawn rotated, like the
## 12 skin wedges. Plates do not follow the aim and do not change with the skin burn band. Tier 0 draws nothing.

const MAX_TIER: int = 3
const CORNER_COUNT: int = 4
const BRIDGE_COUNT: int = 4
const LIP_COUNT: int = 16
## Body cells (`cinder_plate_*`) and their glow twins in the glow sheets.
const SLOT_CORNER: String = "cinder_plate_corner"
const SLOT_BRIDGE: String = "cinder_plate_bridge"
const SLOT_LIP: String = "cinder_plate_lip"
const SLOT_CAP: String = "cinder_plate_cap"
const SLOT_CORNER_TRIM: String = "cinder_plate_corner_trim"
const SLOT_BRIDGE_TRIM: String = "cinder_plate_bridge_trim"
const SLOT_LIP_DIODE: String = "cinder_plate_lip_diode"
const SLOT_CAP_TRIM: String = "cinder_plate_cap_trim"
## The hull upgrade row whose run level picks the tier.
const UPGRADE_ID: String = "hull_integrity"


## Corner plate `k` (0..3) sits on the diagonals: 45, 135, 225, 315 degrees clockwise from up.
static func corner_angle(k: int) -> float:
	return TAU * (float(k) + 0.5) / float(CORNER_COUNT)


## Bridge plate `k` (0..3) sits on the cardinals: up, right, down, left.
static func bridge_angle(k: int) -> float:
	return TAU * float(k) / float(BRIDGE_COUNT)


## Lip segment `k` (0..15), centered between the 22.5 degree marks.
static func lip_angle(k: int) -> float:
	return TAU * (float(k) + 0.5) / float(LIP_COUNT)


## Teal diode strips light every second lip segment.
static func lip_has_diode(k: int) -> bool:
	return k % 2 == 0


## Plate tier (0..3) for a hull level, from the tier table (`plates` param of the hull rows).
static func tier_for_level(model: VisualTierModel, level: int) -> int:
	var def: VisualTierDef = model.def_for(UPGRADE_ID, level)
	if def == null:
		return 0
	return clampi(roundi(def.param("plates", 0.0)), 0, MAX_TIER)


## Quads drawn at `tier` in the body layer (corner + bridge + lip + cap), for budget tests.
static func quad_count(tier: int) -> int:
	var n: int = 0
	if tier >= 1:
		n += CORNER_COUNT
	if tier >= 2:
		n += BRIDGE_COUNT
	if tier >= 3:
		n += LIP_COUNT + CORNER_COUNT
	return n
