class_name FrameMods
extends RefCounted
## Cinder frame modifiers as plain numbers (design 11 section 1; M3-22). Built by `SimConfigLoader`
## from a `FrameDef`, or by hand in tests. Defaults are neutral (all x1.0 / +0, no passive): VANGUARD.
## Stat modifiers enter `StatResolver` through `ExternalMults` (`to_external`): multipliers apply after the
## Type D product and after the Type C hard-cap clamp (so a frame may push `cycle_rate` above 12), additive
## bonuses apply before the Type C clamp. `scrap_mult` / `data_mult` scale kill rewards (M6 frames only).

const PASSIVE_NONE: int = 0
const PASSIVE_BASTION: int = 1  ## no single hit deals more than BASTION_HIT_CAP of max hull
const PASSIVE_OVERCLOCK: int = 2  ## each kill +1% fire rate until the wave ends (cap OVERCLOCK_CAP)
const PASSIVE_SCRAP_TITHE: int = 3  ## M6, rejected by SimWorld
const PASSIVE_FIRST_SIGHT: int = 4  ## M6, rejected by SimWorld

const BASTION_HIT_CAP: float = 0.20
const OVERCLOCK_CAP: int = 20  ## percent

var hull_mult: float = 1.0
var plating_add: float = 0.0
var nano_mult: float = 1.0
var cycle_mult: float = 1.0
var optic_mult: float = 1.0
var laser_mult: float = 1.0
var crit_add: float = 0.0
var crit_mult_mult: float = 1.0
var scrap_mult: float = 1.0
var data_mult: float = 1.0
var passive: int = PASSIVE_NONE
## False for frames the sim must not run yet (M6 rows): SimWorld falls back to neutral.
var implemented: bool = true


func is_neutral() -> bool:
	return (
		hull_mult == 1.0
		and plating_add == 0.0
		and nano_mult == 1.0
		and cycle_mult == 1.0
		and optic_mult == 1.0
		and laser_mult == 1.0
		and crit_add == 0.0
		and crit_mult_mult == 1.0
		and scrap_mult == 1.0
		and data_mult == 1.0
		and passive == PASSIVE_NONE
	)


## True when the sim can run this frame (implemented flag set and a passive the sim knows).
func is_runnable() -> bool:
	return implemented and (passive == PASSIVE_NONE or passive == PASSIVE_BASTION or passive == PASSIVE_OVERCLOCK)


## The stat part as `ExternalMults` (null when there is nothing to apply, keeping the plain resolver path).
func to_external() -> ExternalMults:
	var m: ExternalMults = ExternalMults.new()
	m.hull_integrity_mult = hull_mult
	m.plating_pct_add = plating_add
	m.nano_repair_mult = nano_mult
	m.cycle_rate_mult = cycle_mult
	m.optic_range_mult = optic_mult
	m.laser_output_mult = laser_mult
	m.crit_chance_add = crit_add
	m.crit_mult_mult = crit_mult_mult
	return m


## Stable text of every field, used by `ConfigHash` (floats as raw bits).
func hash_text(frame_id: String) -> String:
	var fl: PackedFloat64Array = PackedFloat64Array(
		[
			hull_mult,
			plating_add,
			nano_mult,
			cycle_mult,
			optic_mult,
			laser_mult,
			crit_add,
			crit_mult_mult,
			scrap_mult,
			data_mult
		]
	)
	return "frame:%s;p%d;%s" % [frame_id, passive, fl.to_byte_array().hex_encode()]
