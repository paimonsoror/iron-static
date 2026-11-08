class_name ProjectileSystem
extends RefCounted
## Moves enemy bolts, applies hits on Cinder and expires bolts (M1-12; GDD 02 section 2, TECH 2.4-2.5).


static func step(world: SimWorld) -> void:
	var p: ProjectileStore = world.projectiles
	if p.alive_count == 0:
		return
	var reach: float = world.config.tuning.cinder_radius
	var reach_sq: float = reach * reach
	for i: int in p.high_water:
		if p.alive[i] == 0:
			continue
		var x: float = p.pos_x[i] + p.vel_x[i] * SimWorld.DT
		var y: float = p.pos_y[i] + p.vel_y[i] * SimWorld.DT
		p.pos_x[i] = x
		p.pos_y[i] = y
		if x * x + y * y <= reach_sq:
			EnemyAttackSystem.hit_cinder(world, p.damage[i], p.owner_type[i])
			p.release(i)
			continue
		p.ttl_ticks[i] -= 1
		if p.ttl_ticks[i] <= 0:
			p.release(i)
