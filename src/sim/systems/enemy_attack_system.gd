class_name EnemyAttackSystem
extends RefCounted
## Enemy offense (M1-11 melee, M1-12 lancer firing). GDD 02 sections 2, 6, 12; GDD 03 sections 1.1, 2.
##
## Melee behaviors (melee, melee_boss) bite once per `melee_interval_s` while within `melee_range + MELEE_SLACK`
## of the origin; raw damage = dmg * min(bite_cap, (1 + bite_gain) ^ melee_hits).
## Ranged behavior fires a bolt every `lancer_fire_s` while at (or inside) its stand-off distance.
## death_cause (impl): `_hit_cinder` sets run.death_cause to the attacker type right before apply_hit and
## restores the previous value unless that hit killed Cinder, so only a lethal hit leaves a cause behind.

const MELEE_SLACK: float = 0.01  ## contact tolerance in meters (GDD task spec)


static func step(world: SimWorld) -> void:
	var store: EnemyStore = world.enemies
	var t: SimTuning = world.config.tuning
	var melee_reach: float = t.melee_range + MELEE_SLACK
	var melee_reach_sq: float = melee_reach * melee_reach
	var standoff: float = lancer_standoff(world)
	var ranged_reach: float = standoff + MELEE_SLACK
	var ranged_reach_sq: float = ranged_reach * ranged_reach
	var melee_gap: int = Ticks.from_seconds(t.melee_interval_s)
	var fire_gap: int = Ticks.from_seconds(t.lancer_fire_s)
	var tick: int = world.tick
	for i: int in store.high_water:
		if store.alive[i] == 0:
			continue
		if not world.cinder.alive:
			return
		if tick < store.next_attack_tick[i]:
			continue
		var x: float = store.pos_x[i]
		var y: float = store.pos_y[i]
		var d2: float = x * x + y * y
		var type: int = store.type_id[i]
		if world.type_behavior[type] == SimWorld.BEH_RANGED:
			if d2 <= ranged_reach_sq:
				store.next_attack_tick[i] = tick + fire_gap
				_fire_bolt(world, type, x, y, store.dmg[i])
		elif d2 <= melee_reach_sq:
			var mult: float = minf(t.bite_cap, pow(1.0 + t.bite_gain, float(store.melee_hits[i])))
			store.melee_hits[i] += 1
			store.next_attack_tick[i] = tick + melee_gap
			hit_cinder(world, store.dmg[i] * mult, type)


## Lancer stand-off distance: clamp(max(range_min, factor * optic_range), 0, cap) (same formula as MovementSystem).
static func lancer_standoff(world: SimWorld) -> float:
	var t: SimTuning = world.config.tuning
	return clampf(maxf(t.lancer_range_min, t.lancer_range_factor * world.stats.optic_range), 0.0, t.lancer_range_cap)


## Applies one enemy hit through the intake pipeline, pushes CINDER_HIT, tracks death_cause (see header).
## Shared with ProjectileSystem.
static func hit_cinder(world: SimWorld, raw: float, attacker_type: int) -> void:
	var prev_cause: int = world.run.death_cause
	world.run.death_cause = attacker_type
	var taken: float = world.cinder.apply_hit(raw, world.stats, world.config.tuning)
	if world.cinder.alive:
		world.run.death_cause = prev_cause
	world.events.push(SimEventKind.CINDER_HIT, roundi(taken), attacker_type)


static func _fire_bolt(world: SimWorld, type: int, x: float, y: float, damage: float) -> void:
	var p: ProjectileStore = world.projectiles
	var j: int = p.alloc()
	if j < 0:
		return  # store full: the shot is dropped (timer already advanced)
	var dist: float = sqrt(x * x + y * y)
	var speed: float = world.config.tuning.lancer_bolt_speed
	var inv: float = 0.0 if dist <= 0.0 else 1.0 / dist
	p.pos_x[j] = x
	p.pos_y[j] = y
	p.vel_x[j] = -x * inv * speed
	p.vel_y[j] = -y * inv * speed
	p.damage[j] = damage
	p.ttl_ticks[j] = world.bolt_ttl_ticks()
	p.owner_type[j] = type
