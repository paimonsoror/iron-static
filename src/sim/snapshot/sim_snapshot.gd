class_name SimSnapshot
extends RefCounted
## Serializes a live SimWorld and rebuilds it so the continued run follows the identical hash path
## (TECH_ARCHITECTURE 5.3, M3-09). Format: `var_to_bytes` of a Dictionary of scalars, text and Packed arrays
## (never objects). The caller wraps it in `SaveCodec` (magic ISNP, M3-13).
## Restore builds a fresh `SimWorld(cfg)` (which derives stats, type tables, Bastion cap, the grid...) and then
## overwrites the saved state, so derived data is rebuilt, not stored. `SnapshotFields` classifies every state
## variable. **(impl)** BigNum is stored as exact mantissa and exponent (text would lose bits and break the hash
## path); the header also carries the BigNum text for display.

const FORMAT: int = 1


static func capture(world: SimWorld, run_id: int = -1) -> PackedByteArray:
	var cfg: SimConfig = world.config
	var eco: EconomyState = world.economy
	var d: Dictionary = {
		"format": FORMAT,
		"sim_version": SimVersion.CURRENT,
		"config_hash": ConfigHash.compute(cfg),
		"seed": cfg.seed_value,
		"run_id": run_id,
		"tick": world.tick,
		"wave": world.wave,
		"data_run": eco.data_run.to_text(),
		"frame_id": cfg.frame_id,
		"sector": cfg.sector,
		"best_wave_s1": cfg.best_wave_s1,
		"ruleset": cfg.ruleset,
		"mode": cfg.wave_mode,
		"debug_invulnerable": cfg.debug_invulnerable,
		"wave_tick": world.wave_tick,
		"level_hp": world.level_hp,
		"level_atk": world.level_atk,
		"laser_charge": world.laser_charge,
		"next_wave_is_boss": world.next_wave_is_boss,
		"tick_scrap": world.tick_scrap,
		"tick_data": world.tick_data,
		"overclock_kills": world.overclock_kills,
		"run_levels": world.run_levels,
		"patch_picks": world.patches.picks,
		"draft":
		{
			"open": world.draft.open,
			"wave": world.draft.wave,
			"offers": world.draft.offers,
			"rerolls_used": world.draft.rerolls_used
		},
		"visible": world.visible,
		"economy": _economy(eco),
		"run": _run(world.run),
		"cinder": _cinder(world.cinder),
		"enemies": world.enemies.save_state(),
		"projectiles": world.projectiles.save_state(),
		"plan": _plan(world.plan),
		"rng": _rng(world),
		"input_log": _log(world.input_log),
	}
	return var_to_bytes(d)


## Header only; null for bytes that are not a snapshot of this format.
static func peek(bytes: PackedByteArray) -> SnapshotInfo:
	var d: Dictionary = _decode(bytes)
	if d.is_empty():
		return null
	var i: SnapshotInfo = SnapshotInfo.new()
	i.format = d["format"]
	i.sim_version = d["sim_version"]
	i.config_hash = d["config_hash"]
	i.seed_value = d["seed"]
	i.run_id = d["run_id"]
	i.tick = d["tick"]
	i.wave = d["wave"]
	i.data_run = d["data_run"]
	i.frame_id = d["frame_id"]
	i.sector = d["sector"]
	i.best_wave_s1 = d["best_wave_s1"]
	i.ruleset = d["ruleset"]
	i.wave_mode = _mode(d)
	i.debug_invulnerable = d["debug_invulnerable"]
	return i


## Rebuilds the world. Null when the bytes are malformed, `sim_version` or `config_hash` differ from this build
## and `cfg`, or `cfg` does not carry the recorded run inputs (seed, sector, best wave, ruleset, frame...).
static func restore(cfg: SimConfig, bytes: PackedByteArray) -> SimWorld:
	var d: Dictionary = _decode(bytes)
	if d.is_empty():
		return null
	var sim_version: int = d["sim_version"]
	var saved_hash: String = d["config_hash"]
	if sim_version != SimVersion.CURRENT or saved_hash != ConfigHash.compute(cfg):
		return null
	var seed_value: int = d["seed"]
	var sector: int = d["sector"]
	var best: int = d["best_wave_s1"]
	var ruleset: String = d["ruleset"]
	var invuln: bool = d["debug_invulnerable"]
	var frame_id: String = d["frame_id"]
	if (
		seed_value != cfg.seed_value
		or sector != cfg.sector
		or best != cfg.best_wave_s1
		or ruleset != cfg.ruleset
		or _mode(d) != cfg.wave_mode
		or invuln != cfg.debug_invulnerable
		or frame_id != cfg.frame_id
	):
		return null
	var w: SimWorld = SimWorld.new(cfg)
	if not _apply(w, d):
		return null
	return w


static func _decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 8:  # shorter than any encoded Dictionary header (also avoids an engine error log)
		return {}
	var v: Variant = bytes_to_var(bytes)  # no objects: bytes_to_var never instantiates them
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = v
	for key: String in ["format", "sim_version", "config_hash", "seed", "tick", "economy", "enemies", "rng"]:
		if not d.has(key):
			return {}
	var fmt: int = d["format"]
	if fmt != FORMAT:
		return {}
	return d


static func _apply(w: SimWorld, d: Dictionary) -> bool:
	w.tick = d["tick"]
	w.wave = d["wave"]
	w.wave_tick = d["wave_tick"]
	w.level_hp = d["level_hp"]
	w.level_atk = d["level_atk"]
	w.laser_charge = d["laser_charge"]
	w.next_wave_is_boss = d["next_wave_is_boss"]
	w.tick_scrap = d["tick_scrap"]
	w.tick_data = d["tick_data"]
	w.overclock_kills = d["overclock_kills"]
	w.run_levels = d["run_levels"]
	w.visible = d["visible"]
	var picks: PackedInt32Array = d["patch_picks"]
	if picks.size() != w.patches.picks.size():
		return false
	w.patches.set_picks(picks)  # before resolve_stats: the patches are part of the stat pipeline
	var draft: Dictionary = _sub(d, "draft")
	var offers: PackedInt32Array = draft["offers"]
	w.draft.open = draft["open"]
	w.draft.wave = draft["wave"]
	w.draft.offers = offers
	var used: int = draft.get("rerolls_used", 0)
	w.draft.rerolls_used = used
	w.stats = w.resolve_stats()
	_apply_economy(w.economy, _sub(d, "economy"))
	_apply_run(w.run, _sub(d, "run"))
	_apply_cinder(w.cinder, _sub(d, "cinder"))
	if not w.enemies.load_state(_sub(d, "enemies")) or not w.projectiles.load_state(_sub(d, "projectiles")):
		return false
	_apply_plan(w.plan, _sub(d, "plan"))
	var rng: Array = d["rng"]
	var streams: Array[Rng] = w.rng_streams()
	if rng.size() != streams.size():
		return false
	for k: int in streams.size():
		var st: PackedInt64Array = rng[k]
		streams[k].set_state(st)
	_apply_log(w.input_log, _sub(d, "input_log"))
	w.grid.rebuild(w.enemies)
	w.events = SimEvents.new()
	w.events.tick = w.tick
	return true


static func _economy(e: EconomyState) -> Dictionary:
	return {
		"scrap_m": e.scrap.m,
		"scrap_e": e.scrap.e,
		"data_m": e.data_run.m,
		"data_e": e.data_run.e,
		"wave_kill_scrap": e.wave_kill_scrap,
		"scrap_frac": e.scrap_frac,
		"conversions": e.conversions,
	}


static func _apply_economy(e: EconomyState, d: Dictionary) -> void:
	var sm: float = d["scrap_m"]
	var se: int = d["scrap_e"]
	var dm: float = d["data_m"]
	var de: int = d["data_e"]
	e.scrap = BigNum.new(sm, se)
	e.data_run = BigNum.new(dm, de)
	e.wave_kill_scrap = d["wave_kill_scrap"]
	e.scrap_frac = d["scrap_frac"]
	e.conversions = d["conversions"]


static func _run(r: RunStats) -> Dictionary:
	return {
		"kills": r.kills,
		"kills_by_type": r.kills_by_type,
		"scrap_earned": r.scrap_earned,
		"data_earned": r.data_earned,
		"damage_dealt": r.damage_dealt,
		"death_wave": r.death_wave,
		"death_cause": r.death_cause,
		"spawn_throttled": r.spawn_throttled,
		"ended": r.ended,
	}


static func _apply_run(r: RunStats, d: Dictionary) -> void:
	r.kills = d["kills"]
	r.kills_by_type = d["kills_by_type"]
	r.scrap_earned = d["scrap_earned"]
	r.data_earned = d["data_earned"]
	r.damage_dealt = d["damage_dealt"]
	r.death_wave = d["death_wave"]
	r.death_cause = d["death_cause"]
	r.spawn_throttled = d["spawn_throttled"]
	r.ended = d["ended"]


static func _cinder(c: CinderState) -> Dictionary:
	return {"hp": c.hp, "max_hp": c.max_hp, "band": c.band, "alive": c.alive, "invulnerable": c.invulnerable}


static func _apply_cinder(c: CinderState, d: Dictionary) -> void:
	c.hp = d["hp"]
	c.max_hp = d["max_hp"]
	c.band = d["band"]
	c.alive = d["alive"]
	c.invulnerable = d["invulnerable"]


static func _plan(p: WavePlanState) -> Dictionary:
	var n: int = p.count
	return {
		"wave": p.wave,
		"built": p.built,
		"count": n,
		"cursor": p.cursor,
		"carried": p.carried,
		"dropped_carry": p.dropped_carry,
		"dropped_slots": p.dropped_slots,
		"type_index": p.type_index.slice(0, n),
		"spawn_tick": p.spawn_tick.slice(0, n),
		"angle_idx": p.angle_idx.slice(0, n),
		"spawned": p.spawned.slice(0, n),
	}


static func _apply_plan(p: WavePlanState, d: Dictionary) -> void:
	p.wave = d["wave"]
	p.built = d["built"]
	p.count = d["count"]
	p.cursor = d["cursor"]
	p.carried = d["carried"]
	p.dropped_carry = d["dropped_carry"]
	p.dropped_slots = d["dropped_slots"]
	var cap: int = p.capacity()
	p.type_index = EnemyStore._fit_i32(d["type_index"], cap)
	p.spawn_tick = EnemyStore._fit_i32(d["spawn_tick"], cap)
	p.angle_idx = EnemyStore._fit_i32(d["angle_idx"], cap)
	p.spawned = EnemyStore._fit_u8(d["spawned"], cap)


static func _rng(w: SimWorld) -> Array:
	var out: Array = []
	for r: Rng in w.rng_streams():
		out.append(r.get_state())
	return out


static func _log(l: InputLog) -> Dictionary:
	return {"ticks": l.ticks, "kinds": l.kinds, "arg_a": l.arg_a, "arg_b": l.arg_b}


static func _apply_log(l: InputLog, d: Dictionary) -> void:
	l.ticks = d["ticks"]
	l.kinds = d["kinds"]
	l.arg_a = d["arg_a"]
	l.arg_b = d["arg_b"]


static func _sub(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d[key]
	var sub: Dictionary = v
	return sub


## Wave mode of a snapshot; a pre-M4 snapshot has no "mode" key and is a TIMED run.
static func _mode(d: Dictionary) -> String:
	var v: Variant = d.get("mode", SimConfig.MODE_TIMED)
	return v if typeof(v) == TYPE_STRING else SimConfig.MODE_TIMED
