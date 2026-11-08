class_name WavePlanner
extends RefCounted
## Builds one wave's spawn plan into `world.plan` (GDD 02 section 6, GDD 03 sections 5 and 7). All randomness
## comes from `world.rng_spawn`. Plan entries end up sorted by spawn tick (stable), each with a type index and
## a start angle index into SinCosTable.
##
## Slot-rule interpretation (M1-08; used by `build`):
##  - Budget N = slots_for_wave(wave). Boss waves (wave % boss_interval == 0) use floor(boss_slot_fraction * N)
##    normal slots plus one boss entry (a separate unit outside the slot budget) due at boss_spawn_s.
##  - Types eligible: not boss, spawn_weight > 0, first_wave <= wave; effective weight is
##    weight * min(1, (wave - first_wave + 1) / ramp_waves).
##  - Fill loop while remaining > 0: draw a type by weight; accept if def.slots <= remaining + slot_overflow;
##    a rejected draw is redrawn up to reject_limit times, then a skitter is used (1 slot, always accepted).
##    Accepted slots are subtracted (remaining may go to -overflow); filling stops when remaining <= 0.
##  - Spawn time for the entry starting at slot index i: t = spawn_seconds * (i + u) / budget seconds,
##    u uniform [0,1), Ticks.from_seconds, clamped to [0, SPAWN_TICKS - 1]. On boss waves `budget` is the
##    normal-slot budget so the normals still spread across the whole spawn phase (impl).
##  - Angles: walking in time order, each not-yet-assigned entry starts a flank group with probability
##    p = f / (f + (1 - f) * mean_group) where f = flank_fraction and mean_group = (flank_min + flank_max) / 2,
##    which makes about f of all ENEMIES (not decisions) belong to groups, as GDD 02 section 6 states (60%
##    uniform, 40% in groups). Using f directly per decision would put about 75% of enemies in groups (impl).
##    A group is range_int(flank_min, flank_max) consecutive entries (cut at the plan end) sharing a center
##    angle; each member is center +- uniform flank_half_angle_deg. Others are uniform over the table.

const SKITTER_ID: String = "skitter"
const DEG_PER_TURN: float = 360.0


## Carried-over entries (`plan.carried`, tick 0) stay in front; the sort is stable so they spawn first.
## Fills `world.plan` for `world.plan.wave` and sets `built = true`. Returns how many entries were placed in
## flank groups (diagnostics and tests; callers may ignore it).
static func build(world: SimWorld) -> int:
	var plan: WavePlanState = world.plan
	var t: SimTuning = world.config.tuning
	var wave: int = plan.wave
	plan.count = plan.carried  # carried-over entries (if any) lead the plan
	plan.cursor = 0
	var n_total: int = Curves.slots_for_wave(wave, t.n_base, t.n_coef, t.n_exp, t.n_cap)
	var budget: int = n_total
	var boss_type: int = -1
	if world.is_boss_wave(wave):
		budget = floori(t.boss_slot_fraction * float(n_total))
		boss_type = _boss_type(world)
	_fill_normals(world, wave, budget)
	if boss_type >= 0 and plan.count < plan.capacity():
		var k: int = plan.count
		plan.type_index[k] = boss_type
		plan.spawn_tick[k] = Ticks.from_seconds(t.boss_spawn_s)
		plan.spawned[k] = 0
		plan.count = k + 1
	elif boss_type >= 0:
		plan.dropped_slots += 1
	_sort_by_tick(plan)
	var grouped: int = _assign_angles(world)
	plan.built = true
	return grouped


static func _boss_type(world: SimWorld) -> int:
	for i: int in world.config.enemies.size():
		if world.type_is_boss[i] != 0:
			return i
	return -1


static func _skitter_type(world: SimWorld) -> int:
	for i: int in world.config.enemies.size():
		if world.config.enemies[i].id == SKITTER_ID:
			return i
	return 0


static func _fill_normals(world: SimWorld, wave: int, budget: int) -> void:
	var plan: WavePlanState = world.plan
	var t: SimTuning = world.config.tuning
	var rng: Rng = world.rng_spawn
	var defs: Array[EnemyDef] = world.config.enemies
	var weights: PackedFloat64Array = PackedFloat64Array()
	if weights.resize(defs.size()) != OK:
		push_error("WavePlanner: weights resize failed")
		return
	var total_w: float = 0.0
	for i: int in defs.size():
		var d: EnemyDef = defs[i]
		var w: float = 0.0
		if world.type_is_boss[i] == 0 and d.spawn_weight > 0.0 and d.first_wave <= wave:
			var ramp: float = float(wave - d.first_wave + 1) / float(maxi(1, t.ramp_waves))
			w = d.spawn_weight * minf(1.0, ramp)
		weights[i] = w
		total_w += w
	var skitter: int = _skitter_type(world)
	var remaining: int = budget
	var used: int = 0
	var cap: int = plan.capacity()
	while remaining > 0 and plan.count < cap:
		var chosen: int = skitter
		var attempts: int = 0
		while attempts < t.reject_limit:
			attempts += 1
			var pick: int = _draw(rng, weights, total_w, skitter)
			if defs[pick].slots <= remaining + t.slot_overflow:
				chosen = pick
				break
		var k: int = plan.count
		plan.type_index[k] = chosen
		var u: float = rng.next_float()
		var secs: float = float(t.spawn_seconds) * (float(used) + u) / float(budget)
		plan.spawn_tick[k] = clampi(Ticks.from_seconds(secs), 0, Ticks.SPAWN_TICKS - 1)
		plan.spawned[k] = 0
		plan.count = k + 1
		var s: int = maxi(1, defs[chosen].slots)
		remaining -= s
		used += s
	if remaining > 0:
		plan.dropped_slots += remaining  # plan capacity exhausted (see WavePlanState header)


static func _draw(rng: Rng, weights: PackedFloat64Array, total_w: float, fallback: int) -> int:
	if total_w <= 0.0:
		return fallback
	var r: float = rng.next_float() * total_w
	var acc: float = 0.0
	var last: int = fallback
	for i: int in weights.size():
		if weights[i] <= 0.0:
			continue
		acc += weights[i]
		last = i
		if r < acc:
			return i
	return last


## Stable insertion sort of the plan entries by spawn_tick (count is at most a couple hundred).
static func _sort_by_tick(plan: WavePlanState) -> void:
	for i: int in range(1, plan.count):
		var tk: int = plan.spawn_tick[i]
		var ty: int = plan.type_index[i]
		var j: int = i - 1
		while j >= 0 and plan.spawn_tick[j] > tk:
			plan.spawn_tick[j + 1] = plan.spawn_tick[j]
			plan.type_index[j + 1] = plan.type_index[j]
			j -= 1
		plan.spawn_tick[j + 1] = tk
		plan.type_index[j + 1] = ty


static func _assign_angles(world: SimWorld) -> int:
	var plan: WavePlanState = world.plan
	var t: SimTuning = world.config.tuning
	var rng: Rng = world.rng_spawn
	var f: float = t.flank_fraction
	var mean_group: float = 0.5 * float(t.flank_min + t.flank_max)
	var p_start: float = f / (f + (1.0 - f) * mean_group)
	var half_idx: float = t.flank_half_angle_deg / DEG_PER_TURN * float(SinCosTable.SIZE)
	var grouped: int = 0
	var i: int = 0
	while i < plan.count:
		if rng.chance(p_start):
			var size: int = mini(rng.range_int(t.flank_min, t.flank_max), plan.count - i)
			var center: int = rng.range_int(0, SinCosTable.SIZE - 1)
			for m: int in size:
				var off: int = roundi((rng.next_float() * 2.0 - 1.0) * half_idx)
				plan.angle_idx[i + m] = (center + off) & SinCosTable.MASK
			i += size
			grouped += size
		else:
			plan.angle_idx[i] = rng.range_int(0, SinCosTable.SIZE - 1)
			i += 1
	return grouped
