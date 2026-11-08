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
## floor of `min_damage_floor` of the post-percent damage, then subtract and clamp. Returns the damage
## after plating (what `hp` was reduced by, before clamping at 0); 0 when already dead.
func apply_hit(raw: float, stats: StatBlock, tuning: SimTuning) -> float:
	if not alive:
		return 0.0
	var r1: float = raw * (1.0 - minf(tuning.plating_pct_cap, stats.plating_pct))
	var r2: float = maxf(r1 - stats.plating_flat, tuning.min_damage_floor * r1)
	if hit_cap_frac > 0.0:
		r2 = minf(r2, hit_cap_frac * max_hp)
	hp = clampf(hp - r2, 0.0, max_hp)
	if hp <= 0.0 and not invulnerable:
		alive = false
	return r2
