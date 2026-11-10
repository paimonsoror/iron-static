class_name CinderState
extends RefCounted
## Cinder's health and the intake pipeline (GDD 02 section 12 steps 2-4 and 6).

var hp: float = 0.0
var max_hp: float = 0.0
## Integrity band 0-3 (GDD 02 section 12.1); written by ExposureSystem.
var band: int = 0
var alive: bool = true
## debug_invulnerable: hp is clamped at 0 but Cinder never dies.
var invulnerable: bool = false
## Bastion (M3-22): when > 0 no single hit takes more than this fraction of `max_hp` (set by SimWorld). Not hashed.
var hit_cap_frac: float = 0.0


func setup(new_max_hp: float, is_invulnerable: bool) -> void:
	max_hp = new_max_hp
	hp = new_max_hp
	band = 0
	alive = true
	invulnerable = is_invulnerable


## Applies one incoming hit of `raw` damage. Steps: plating percent (capped), then flat plating with a
## floor of `min_damage_floor` of the post-percent damage, then the skin burn hardening multiplier of the current
## band (R1-05, `burn_dr_b1..3`; band 0 takes full damage), then the Bastion hit cap, then subtract and clamp.
## Returns the damage after all of that (what `hp` was reduced by, before clamping at 0); 0 when already dead.
func apply_hit(raw: float, stats: StatBlock, tuning: SimTuning) -> float:
	if not alive:
		return 0.0
	var r1: float = raw * (1.0 - minf(tuning.plating_pct_cap, stats.plating_pct))
	var r2: float = maxf(r1 - stats.plating_flat, tuning.min_damage_floor * r1)
	r2 *= burn_damage_mult(tuning)
	if hit_cap_frac > 0.0:
		r2 = minf(r2, hit_cap_frac * max_hp)
	hp = clampf(hp - r2, 0.0, max_hp)
	if hp <= 0.0 and not invulnerable:
		alive = false
	return r2


## Damage taken multiplier of the current integrity band (R1-05): 1.0 in band 0, `burn_dr_b1..3` in bands 1-3.
func burn_damage_mult(tuning: SimTuning) -> float:
	return band_damage_mult(band, tuning)


static func band_damage_mult(for_band: int, tuning: SimTuning) -> float:
	match for_band:
		1:
			return tuning.burn_dr_b1
		2:
			return tuning.burn_dr_b2
		3:
			return tuning.burn_dr_b3
	return 1.0
