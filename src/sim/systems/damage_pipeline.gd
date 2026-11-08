class_name DamagePipeline
extends RefCounted
## Laser damage pipeline, MVP subset (GDD 02 section 8): step 1-3 base `laser_output`, step 4 no
## multipliers, step 5 crit, step 9 floor and final integer. Step 10 (feedback) is view-side.


## Rolls the crit with the `crit` stream (always one draw, so the stream advances identically per shot)
## and returns the final integer damage (>= 1). `crit_out[0]` is set to 1 on a crit, else 0.
static func laser_damage(stats: StatBlock, rng: Rng, crit_out: PackedInt32Array) -> int:
	var d: float = stats.laser_output
	var crit: bool = rng.chance(stats.crit_chance)
	crit_out[0] = 1 if crit else 0
	if crit:
		d *= stats.crit_mult
	return maxi(1, floori(d))
