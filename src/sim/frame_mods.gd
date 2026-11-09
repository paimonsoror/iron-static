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

const BASTION_HIT_CAP: float = 0.20  ## default of `bastion_cap_frac` (data/frames.csv)
const OVERCLOCK_PER_KILL: float = 0.01  ## default of `overclock_per_kill`
const OVERCLOCK_CAP_FRAC: float = 0.20  ## default of `overclock_cap`
const OVERCLOCK_SCALE: int = 100000  ## fixed-point scale of the per-kill bonus (integer math, M3 impl)
const OVERCLOCK_CAP: int = 20  ## default kill cap (= OVERCLOCK_CAP_FRAC / OVERCLOCK_PER_KILL)

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
## Passive strengths (data/frames.csv; defaults equal the pre-data constants). Bastion: no hit above
## `bastion_cap_frac` of max hull. Overclock: `overclock_per_kill` fire-rate bonus per kill this wave, at most
## `overclock_cap` in total. Read only when the matching passive is active.
var bastion_cap_frac: float = BASTION_HIT_CAP
var overclock_per_kill: float = OVERCLOCK_PER_KILL
var overclock_cap: float = OVERCLOCK_CAP_FRAC
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


## Kills after which Overclock stops growing: `overclock_cap / overclock_per_kill` (20 for the 0.20 / 0.01 default).
func overclock_kill_cap() -> int:
	if overclock_per_kill <= 0.0:
		return 0
	return maxi(0, floori(overclock_cap / overclock_per_kill + 0.000001))


## Per-kill Overclock bonus in `OVERCLOCK_SCALE` units (1000 for 1%), the integer the laser system multiplies.
func overclock_scale() -> int:
	return maxi(0, roundi(overclock_per_kill * float(OVERCLOCK_SCALE)))


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
	var text: String = "frame:%s;p%d;%s" % [frame_id, passive, fl.to_byte_array().hex_encode()]
	if (
		bastion_cap_frac != BASTION_HIT_CAP
		or overclock_per_kill != OVERCLOCK_PER_KILL
		or overclock_cap != OVERCLOCK_CAP_FRAC
	):
		# Appended only for non-default strengths so every default frame keeps its hash.
		var pp: PackedFloat64Array = PackedFloat64Array([bastion_cap_frac, overclock_per_kill, overclock_cap])
		text += ";pp" + pp.to_byte_array().hex_encode()
	return text
