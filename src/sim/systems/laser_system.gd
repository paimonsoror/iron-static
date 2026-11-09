class_name LaserSystem
extends RefCounted
## Cinder's Laser Cycle (GDD 02 sections 3, 4, 8; 03 section 3). Fixed-point accumulator:
## charge += roundi(cycle_rate * 1000) per tick; a shot costs tick_rate * 1000. Each shot re-targets with
## grid.nearest (smallest distance, lowest spawn_id on ties) within optic_range. With no target the charge is
## capped at one shot. Kills release the enemy and pay RewardCalc (half if stale)
## into the tick accumulators. The grid must be rebuilt
## before this runs; killed entries are skipped by grid.nearest afterwards.

const CHARGE_UNIT: int = 1000  ## fixed-point scale of the shot accumulator
const MAX_SHOTS_PER_TICK: int = 64  ## safety bound (cycle_rate caps far below this)

static var _crit_out: PackedInt32Array = PackedInt32Array([0])


static func step(world: SimWorld) -> void:
	var stats: StatBlock = world.stats
	var shot_cost: int = world.config.tuning.tick_rate * CHARGE_UNIT
	var inc: int = roundi(stats.cycle_rate * float(CHARGE_UNIT))
	if world.overclock_kills > 0:
		# Overclock (M3-22): +overclock_per_kill (1% default) per kill this wave, integer fixed point.
		inc += floori(
			float(inc * world.overclock_kills * world.frame_overclock_scale) / float(FrameMods.OVERCLOCK_SCALE)
		)
	world.laser_charge += inc
	var shots: int = 0
	while world.laser_charge >= shot_cost and shots < MAX_SHOTS_PER_TICK:
		var target: int = world.grid.nearest(world.enemies, 0.0, 0.0, stats.optic_range)
		if target < 0:
			world.laser_charge = shot_cost
			return
		world.laser_charge -= shot_cost
		shots += 1
		_fire(world, target)


static func _fire(world: SimWorld, i: int) -> void:
	var store: EnemyStore = world.enemies
	var dmg: int = DamagePipeline.laser_damage(world.stats, world.rng_crit, _crit_out)
	world.events.push(SimEventKind.SHOT_FIRED, i, _crit_out[0])
	world.events.push(SimEventKind.ENEMY_HIT, i, dmg)
	world.run.damage_dealt += float(dmg)
	store.hp[i] -= float(dmg)
	if store.hp[i] <= 0.0:
		_kill(world, i)


static func _kill(world: SimWorld, i: int) -> void:
	var store: EnemyStore = world.enemies
	var type_index: int = store.type_id[i]
	var def: EnemyDef = world.config.enemies[type_index]
	var t: SimTuning = world.config.tuning
	var stale: bool = store.stale[i] != 0
	var level: int = store.level_hp[i]
	world.events.push(SimEventKind.ENEMY_KILLED, i, type_index)
	world.run.kills += 1
	world.run.kills_by_type[type_index] += 1
	var scrap: float = RewardCalc.scrap_for_kill(t, def, level, world.stats.scrap_yield, stale) * world.frame_scrap_mult
	var data: float = (
		RewardCalc.data_for_kill(t, def, level, world.config.sector, stale)
		* world.frame_data_mult
		* world.stats.data_yield
	)
	if world.frame_passive == FrameMods.PASSIVE_OVERCLOCK:
		world.overclock_kills = mini(world.overclock_kills + 1, world.frame_overclock_kill_cap)
	world.run.scrap_earned += scrap  # float shadow totals (tools and HUD read them)
	world.run.data_earned += data
	world.tick_scrap += scrap  # BigNum conversion happens once per tick in EconomySystem.apply_tick
	world.tick_data += data
	store.release(i)
