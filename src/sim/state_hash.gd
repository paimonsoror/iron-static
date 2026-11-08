class_name StateHash
extends RefCounted
## SHA-256 over the deterministic sim state (TECH_ARCHITECTURE 2.1). Packed arrays are hashed as raw bytes
## up to `high_water` / `count`; scalars go through small packed arrays. Not for per-tick use.
## Excluded on purpose: events (view feed), `EnemyStore.cell` and the grid (derived), `query_buf` (scratch).


static func compute(w: SimWorld) -> String:
	var ctx: HashingContext = HashingContext.new()
	if ctx.start(HashingContext.HASH_SHA256) != OK:
		push_error("StateHash: start failed")
		return ""
	_scalars(ctx, w)
	_enemies(ctx, w.enemies)
	_projectiles(ctx, w.projectiles)
	_plan(ctx, w.plan)
	return ctx.finish().hex_encode()


static func _put(ctx: HashingContext, bytes: PackedByteArray) -> void:
	if bytes.is_empty():
		return  # HashingContext.update rejects empty input
	if ctx.update(bytes) != OK:
		push_error("StateHash: update failed")


static func _scalars(ctx: HashingContext, w: SimWorld) -> void:
	var ints: PackedInt64Array = PackedInt64Array(
		[
			w.tick,
			w.wave,
			w.wave_tick,
			w.level_hp,
			w.level_atk,
			w.laser_charge,
			int(w.next_wave_is_boss),
			int(w.cinder.alive),
			w.cinder.band,
			w.run.kills,
			w.run.death_wave,
			w.run.death_cause,
			w.run.spawn_throttled,
			int(w.run.ended),
		]
	)
	_put(ctx, ints.to_byte_array())
	_put(ctx, w.run.kills_by_type.to_byte_array())
	var floats: PackedFloat64Array = PackedFloat64Array(
		[
			w.cinder.hp,
			w.cinder.max_hp,
			w.run.scrap_earned,
			w.run.data_earned,
			w.run.damage_dealt,
			w.stats.laser_output,
			w.stats.cycle_rate,
			w.stats.crit_chance,
			w.stats.crit_mult,
			w.stats.optic_range,
			w.stats.hull_integrity,
			w.stats.nano_repair,
			w.stats.plating_pct,
			w.stats.plating_flat,
		]
	)
	_put(ctx, floats.to_byte_array())
	for r: Rng in w.rng_streams():
		_put(ctx, r.get_state().to_byte_array())


static func _enemies(ctx: HashingContext, s: EnemyStore) -> void:
	var n: int = s.high_water
	_put(ctx, PackedInt64Array([n, s.alive_count]).to_byte_array())
	_put(ctx, s.alive.slice(0, n))
	_put(ctx, s.stale.slice(0, n))
	_put(ctx, s.type_id.slice(0, n))
	for arr: PackedFloat32Array in [s.pos_x, s.pos_y, s.prev_x, s.prev_y, s.radius, s.speed]:
		_put(ctx, arr.slice(0, n).to_byte_array())
	for arr: PackedFloat64Array in [s.hp, s.max_hp, s.dmg]:
		_put(ctx, arr.slice(0, n).to_byte_array())
	for arr: PackedInt32Array in [s.spawn_id, s.born_wave, s.level_hp, s.melee_hits, s.next_attack_tick]:
		_put(ctx, arr.slice(0, n).to_byte_array())


static func _projectiles(ctx: HashingContext, s: ProjectileStore) -> void:
	var n: int = s.high_water
	_put(ctx, PackedInt64Array([n, s.alive_count]).to_byte_array())
	_put(ctx, s.alive.slice(0, n))
	_put(ctx, s.owner_type.slice(0, n))
	for arr: PackedFloat32Array in [s.pos_x, s.pos_y, s.vel_x, s.vel_y]:
		_put(ctx, arr.slice(0, n).to_byte_array())
	_put(ctx, s.damage.slice(0, n).to_byte_array())
	_put(ctx, s.ttl_ticks.slice(0, n).to_byte_array())


static func _plan(ctx: HashingContext, p: WavePlanState) -> void:
	_put(ctx, PackedInt64Array([p.wave, int(p.built), p.count, p.cursor]).to_byte_array())
	_put(ctx, p.type_index.slice(0, p.count).to_byte_array())
	_put(ctx, p.spawn_tick.slice(0, p.count).to_byte_array())
	_put(ctx, p.angle_idx.slice(0, p.count).to_byte_array())
	_put(ctx, p.spawned.slice(0, p.count))
