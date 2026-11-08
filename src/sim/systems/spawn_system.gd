class_name SpawnSystem
extends RefCounted
## Spawns the current wave's planned enemies (GDD 02 section 6). The plan itself is built by `WavePlanner`
## (see its header for the slot-rule interpretation) the first tick `world.plan.built` is false.
## Entries due at `wave_tick` spawn on the arena rim at their start angle. Alive caps (alive_cap_normal for
## normal types, alive_cap_boss for bosses) never drop an entry: it waits and is retried every tick, and
## `run.spawn_throttled` is incremented once per tick in which at least one due entry was held back (impl).
## A full enemy store (spawn_enemy returns -1) is handled the same way.


static func step(world: SimWorld) -> void:
	var plan: WavePlanState = world.plan
	if not plan.built:
		@warning_ignore("return_value_discarded")  # the grouped-entry count is for diagnostics only
		WavePlanner.build(world)
	var t: SimTuning = world.config.tuning
	var normals: int = world.alive_normal_count()
	var bosses: int = world.alive_boss_count()
	var throttled: bool = false
	var i: int = plan.cursor
	while i < plan.count and plan.spawn_tick[i] <= world.wave_tick:
		if plan.spawned[i] == 0:
			var ty: int = plan.type_index[i]
			var is_boss: bool = world.type_is_boss[ty] != 0
			var blocked: bool = bosses >= t.alive_cap_boss if is_boss else normals >= t.alive_cap_normal
			var idx: int = -1
			if not blocked:
				var a: int = plan.angle_idx[i]
				idx = world.spawn_enemy(
					ty, t.arena_radius * SinCosTable.cos_i(a), t.arena_radius * SinCosTable.sin_i(a)
				)
			if idx < 0:
				throttled = true
			else:
				plan.spawned[i] = 1
				if is_boss:
					bosses += 1
					world.events.push(SimEventKind.BOSS_SPAWNED, idx, 0)
				else:
					normals += 1
		i += 1
	if throttled:
		world.run.spawn_throttled += 1
	while plan.cursor < plan.count and plan.spawned[plan.cursor] != 0:
		plan.cursor += 1
