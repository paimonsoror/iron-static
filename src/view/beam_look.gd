class_name BeamLook
extends RefCounted
## Look of the laser beam at one upgrade visual tier (VT-2, docs/design/12 section 4.1). A small value built once
## when the `laser_output` run level crosses a tier; BeamRenderer only reads its fields while drawing. The defaults
## are MK I and equal the pre-tier constants of BeamMath, so an untouched renderer draws exactly as before.
## All px values are at 1080 width (the renderer multiplies by its sprite factor).

## Tier shown (1 = MK I). 0 is never used; MK I is the floor.
var tier: int = 1
var glow_px: float = BeamMath.GLOW_PX
var core_px: float = BeamMath.CORE_PX
var hot_px: float = BeamMath.HOT_PX
## Impact flare size (0 = none) and ring size (0 = none).
var flare_px: float = 0.0
var ring_px: float = 0.0
## 0 = amber glow and `LASER_CORE`, 1 = whiter glow and pure white core.
var whiten: float = 0.0
## Alpha of the teal rim layer (0 = none).
var rim: float = 0.0
## Travelling bright bands (0 = none).
var ripple: int = 0
## Muzzle flare and cone scale.
var muzzle: float = 1.0


## Look of a table row; a null def (no row) is the MK I look.
static func from_def(def: VisualTierDef) -> BeamLook:
	var look := BeamLook.new()
	if def == null:
		return look
	look.tier = def.tier
	look.glow_px = def.param("glow", look.glow_px)
	look.core_px = def.param("core", look.core_px)
	look.hot_px = def.param("hot", look.hot_px)
	look.flare_px = def.param("flare", look.flare_px)
	look.ring_px = def.param("ring", look.ring_px)
	look.whiten = def.param("whiten", look.whiten)
	look.rim = def.param("rim", look.rim)
	look.ripple = int(def.param("ripple", float(look.ripple)))
	look.muzzle = def.param("muzzle", look.muzzle)
	return look


## Look for the `laser_output` run level (shared tier model).
static func for_level(level: int) -> BeamLook:
	return from_def(VisualTierModel.shared().def_for("laser_output", level))


## True for the untouched MK I look (nothing beyond the three strip layers and the crit flare).
func is_plain() -> bool:
	return flare_px <= 0.0 and ring_px <= 0.0 and rim <= 0.0 and ripple <= 0 and whiten <= 0.0
