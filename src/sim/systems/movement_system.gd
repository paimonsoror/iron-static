class_name MovementSystem
extends RefCounted
## Walks every alive enemy toward the origin (Cinder) and stops it at its stand-off distance
## (GDD 02 section 2, 03 section 1.1). Melee behaviors stop at `melee_range`; `ranged` stops at
## clamp(max(lancer_range_min, lancer_range_factor * optic_range), 0, lancer_range_cap).
## Scalar math only, no allocation, no enemy-enemy collision.


static func step(world: SimWorld) -> void:
	var t: SimTuning = world.config.tuning
	var store: EnemyStore = world.enemies
	var ranged_stop: float = clampf(
		maxf(t.lancer_range_min, t.lancer_range_factor * world.stats.optic_range), 0.0, t.lancer_range_cap
	)
	var melee_stop: float = t.melee_range
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		var x: float = store.pos_x[i]
		var y: float = store.pos_y[i]
		store.prev_x[i] = x
		store.prev_y[i] = y
		var stop: float = ranged_stop if world.type_behavior[store.type_id[i]] == SimWorld.BEH_RANGED else melee_stop
		var d2: float = x * x + y * y
		if d2 <= stop * stop:
			continue
		var d: float = sqrt(d2)
		var nd: float = maxf(stop, d - store.speed[i] * SimWorld.DT)
		var k: float = nd / d
		store.pos_x[i] = x * k
		store.pos_y[i] = y * k
