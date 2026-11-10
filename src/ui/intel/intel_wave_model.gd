class_name IntelWaveModel
extends RefCounted
## Pure rows of the Intel Wave panel (M4-19; GDD 02 section 15). Reads a `SimWorld` and never mutates it.
## Rows: current wave and mode, time left (TIMED) or quota left and backstop (PURGE), next boss, next draft,
## enemy slots N(w), stale enemies, then the expected enemy mix of the current wave (one row per type with its
## effective spawn weight share; HP / ATK multipliers, speed and slot cost below). The mix comes from
## `WavePlanner.weights_for_wave`, the same table the planner draws from. Adaptation and active conditions are
## Launch features and have no rows. "NOW" means the current wave is the boss / draft wave.

const MIX_DECIMALS: int = 2


## Rows for the world's current state (new array each call; the panel calls it at most 4 times per second).
static func build(world: SimWorld) -> Array[IntelRow]:
	var rows: Array[IntelRow] = []
	var mode: String = world.config.wave_mode
	rows.append(
		IntelRow.new(
			"wave",
			Strings.get_text("intel.wave.wave"),
			str(world.wave),
			Strings.fill1("mode.chip", "name", Strings.get_text("mode." + mode))
		)
	)
	rows.append(_clock_row(world))
	var boss: int = boss_in(world)
	if boss >= 0:
		rows.append(
			IntelRow.new(
				"boss",
				Strings.get_text("intel.wave.boss"),
				_in_waves(boss),
				Strings.fill1("intel.wave.chain_boss", "n", str(world.config.tuning.boss_interval))
			)
		)
	var draft: int = DraftSystem.waves_until_draft(world)
	if draft >= 0:
		rows.append(
			IntelRow.new(
				"draft",
				Strings.get_text("intel.wave.draft"),
				_in_waves(draft),
				Strings.fill1("intel.wave.chain_draft", "n", str(world.wave + draft))
			)
		)
	rows.append(_slots_row(world))
	rows.append(
		IntelRow.new(
			"stale",
			Strings.get_text("intel.wave.stale"),
			str(world.stale_count()),
			Strings.fill1("intel.wave.chain_stale", "v", NumberFormat.format_percent(world.config.tuning.stale_payout))
		)
	)
	_add_mix_rows(world, rows)
	return rows


## Waves until the next boss as the panel shows it: 0 while a boss wave is running, else
## `SimWorld.waves_until_boss()`. -1 when bosses are off.
static func boss_in(world: SimWorld) -> int:
	if world.config.tuning.boss_interval <= 0:
		return -1
	if world.is_boss_wave(world.wave):
		return 0
	return world.waves_until_boss()


static func _in_waves(n: int) -> String:
	if n <= 0:
		return Strings.get_text("intel.wave.now")
	if n == 1:
		return Strings.get_text("intel.wave.in_one")
	return Strings.fill1("intel.wave.in_many", "n", str(n))


static func _clock_row(world: SimWorld) -> IntelRow:
	if world.config.wave_mode == SimConfig.MODE_PURGE:
		var left: int = ceili(
			float(maxi(PurgeClock.backstop_ticks(world) - world.wave_tick, 0)) / float(Ticks.TICK_RATE)
		)
		return IntelRow.new(
			"quota",
			Strings.get_text("intel.wave.quota"),
			Strings.fill1("hud.mode_purge_left", "n", str(PurgeClock.remaining_quota(world))),
			Strings.fill1("intel.wave.chain_backstop", "n", str(left))
		)
	var secs: int = ceili(float(maxi(Ticks.WAVE_TICKS - world.wave_tick, 0)) / float(Ticks.TICK_RATE))
	return IntelRow.new(
		"time_left",
		Strings.get_text("intel.wave.time_left"),
		Strings.fill1("hud.timer", "n", str(secs)),
		Strings.get_text("intel.wave.chain_timed")
	)


static func _slots_row(world: SimWorld) -> IntelRow:
	var n: int = WavePlanner.slots_for_wave(world, world.wave)
	var next_n: int = WavePlanner.slots_for_wave(world, world.wave + 1)
	var chain: String = Strings.fill1("intel.wave.chain_slots", "n", str(next_n))
	if world.is_boss_wave(world.wave):
		var normals: int = floori(world.config.tuning.boss_slot_fraction * float(n))
		chain = Strings.fill1("intel.wave.chain_boss_slots", "n", str(normals)) + "   " + chain
	return IntelRow.new("slots", Strings.get_text("intel.wave.slots"), str(n), chain)


static func _add_mix_rows(world: SimWorld, rows: Array[IntelRow]) -> void:
	var weights: PackedFloat64Array = WavePlanner.weights_for_wave(world, world.wave)
	var total: float = 0.0
	for w: float in weights:
		total += w
	var defs: Array[EnemyDef] = world.config.enemies
	var boss_row: IntelRow = null
	for i: int in defs.size():
		if world.type_is_boss[i] != 0:
			if world.is_boss_wave(world.wave):
				boss_row = _type_row(defs[i], Strings.get_text("intel.wave.boss_tag"))
			continue
		if weights[i] <= 0.0 or total <= 0.0:
			continue
		rows.append(_type_row(defs[i], NumberFormat.format_percent(weights[i] / total)))
	if boss_row != null:
		rows.append(boss_row)


static func _type_row(def: EnemyDef, value: String) -> IntelRow:
	var chain: String = (
		Strings
		. fill(
			"intel.wave.chain_type",
			{
				"hp": NumberFormat.format_mult(def.hp_mult),
				"atk": NumberFormat.format_mult(def.dmg_mult),
				"spd": NumberFormat.format_float(def.speed, MIX_DECIMALS),
				"slots": str(def.slots),
			}
		)
	)
	return IntelRow.new("type_" + def.id, Strings.get_text("enemy.name." + def.id), value, chain)
