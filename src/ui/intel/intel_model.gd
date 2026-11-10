class_name IntelModel
extends RefCounted
## Pure rows of the Intel Stats panel (M4-18; GDD 02 sections 5 and 15). Reads a `SimWorld` and never mutates it.
## Each row is the final value the sim uses (`world.stats`, the `StatResolver` output) plus the chain that made it:
## Type D `BASE x RUN x FOUNDRY x FRAME x PATCH`, Type C `BASE + RUN + FOUNDRY` then `x FRAME x PATCH`. Neutral
## links (x1, +0) are left out. Frame and patches are separated by resolving the patch-only multipliers apart
## (`PatchEffects.compose(null, ...)`); the product of the two equals the combined multiplier the sim used.
## Numbers go through `NumberFormat`. Rows follow the upgrade table order with DPS after cycle rate, then the patch-only
## stats (data yield always, enemy damage only when a patch changed it), then the burn hardening row (R1-05).

enum Kind { NUM, RATE, PCT, MULT, RANGE }

const KIND_BY_ID: Dictionary[String, int] = {
	"laser_output": Kind.NUM,
	"cycle_rate": Kind.RATE,
	"crit_chance": Kind.PCT,
	"crit_mult": Kind.MULT,
	"optic_range": Kind.RANGE,
	"hull_integrity": Kind.NUM,
	"nano_repair": Kind.RATE,
	"plating_pct": Kind.PCT,
	"scrap_yield": Kind.MULT,
	"reinvest": Kind.PCT,
}
const SEP: String = "   "
const BIG_FROM: float = 1000.0


## Rows for the world's current state (new array each call; the panel calls it at most 4 times per second).
static func build(world: SimWorld) -> Array[IntelRow]:
	var rows: Array[IntelRow] = []
	var cfg: SimConfig = world.config
	var frame: ExternalMults = world.frame_ext if world.frame_ext != null else ExternalMults.new()
	var patch: ExternalMults = PatchEffects.compose(null, world.patches, cfg.patches)
	if patch == null:
		patch = ExternalMults.new()
	for i: int in cfg.upgrades.size():
		if i >= world.visible.size() or world.visible[i] == 0:
			continue
		var def: RunUpgradeDef = cfg.upgrades[i]
		rows.append(_upgrade_row(world, i, def, frame, patch))
		if def.id == "cycle_rate":
			rows.append(_dps_row(world.stats))
	rows.append(_yield_row(world.stats, patch))
	if not is_equal_approx(world.stats.enemy_damage, 1.0):
		rows.append(
			IntelRow.new(
				"enemy_damage",
				Strings.get_text("intel.stats.enemy_damage"),
				NumberFormat.format_mult(world.stats.enemy_damage),
				_token("intel.stats.chain_patch", NumberFormat.format_mult(patch.enemy_damage_mult))
			)
		)
	rows.append(_burn_row(world))
	return rows


## R1-05: the damage reduction of the current skin burn band (`CinderState.burn_damage_mult`), e.g. `-30%` in band 2.
static func _burn_row(world: SimWorld) -> IntelRow:
	var band: int = world.cinder.band
	var mult: float = world.cinder.burn_damage_mult(world.config.tuning)
	var value: String = Strings.get_text("intel.stats.burn_dr_none")
	var chain: String = Strings.get_text("intel.stats.chain_burn_none")
	if band > 0:
		value = "-" + NumberFormat.format_percent(1.0 - mult)
		chain = Strings.fill1("intel.stats.chain_burn_band", "v", str(band))
	return IntelRow.new("burn_dr", Strings.get_text("intel.stats.burn_dr"), value, chain)


## Average damage per second against one target: output x rate x (1 + crit chance x (crit mult - 1)).
static func dps_of(s: StatBlock) -> float:
	var chance: float = clampf(s.crit_chance, 0.0, 1.0)
	return s.laser_output * s.cycle_rate * (1.0 + chance * maxf(s.crit_mult - 1.0, 0.0))


## Final stat value of an upgrade row id from the resolved block (0 for an unknown id).
static func stat_of(s: StatBlock, id: String) -> float:
	var v: float = 0.0
	match id:
		"laser_output":
			v = s.laser_output
		"cycle_rate":
			v = s.cycle_rate
		"crit_chance":
			v = s.crit_chance
		"crit_mult":
			v = s.crit_mult
		"optic_range":
			v = s.optic_range
		"hull_integrity":
			v = s.hull_integrity
		"nano_repair":
			v = s.nano_repair
		"plating_pct":
			v = s.plating_pct
		"scrap_yield":
			v = s.scrap_yield
		"reinvest":
			v = s.reinvest
	return v


static func format_value(kind: int, v: float) -> String:
	match kind:
		Kind.RATE:
			return Strings.fill1("intel.stats.fmt_rate", "v", num(v))
		Kind.PCT:
			return NumberFormat.format_percent(v)
		Kind.MULT:
			return NumberFormat.format_mult(v)
		Kind.RANGE:
			return Strings.fill1("intel.stats.fmt_range", "v", num(v))
	return num(v)


## Plain number: stat-sized values keep up to 2 decimals, thousands and above use the BigNum short form.
static func num(v: float) -> String:
	if absf(v) < BIG_FROM:
		return NumberFormat.format_float(v, 2)
	return NumberFormat.format(BigNum.from_float(v))


static func _upgrade_row(
	world: SimWorld, i: int, def: RunUpgradeDef, frame: ExternalMults, patch: ExternalMults
) -> IntelRow:
	var kind: int = KIND_BY_ID.get(def.id, Kind.NUM)
	var cfg: SimConfig = world.config
	var lvl: int = clampi(world.run_levels[i], 0, def.l_cap)
	var fl: int = cfg.foundry_levels[i] if i < cfg.foundry_levels.size() else 0
	var ff: float = cfg.foundry_f[i] if i < cfg.foundry_f.size() else 0.0
	var parts: PackedStringArray = PackedStringArray()
	parts.append(_token("intel.stats.chain_base", format_value(kind, def.base)))
	if def.kind == "D":
		if lvl > 0:
			parts.append(_token("intel.stats.chain_run", NumberFormat.format_mult(Curves.run_factor(lvl, def.step))))
		if fl > 0:
			parts.append(_token("intel.stats.chain_foundry", NumberFormat.format_mult(Curves.foundry_mult(fl, ff))))
	else:
		var run_inc: float = def.step * float(lvl)
		var f_inc: float = def.step * float(clampi(fl, 0, StatResolver.foundry_cap(def)))
		if run_inc > 0.0:
			parts.append(_token("intel.stats.chain_run", "+" + _delta(kind, run_inc)))
		if f_inc > 0.0:
			parts.append(_token("intel.stats.chain_foundry", "+" + _delta(kind, f_inc)))
	_append_ext(parts, "intel.stats.chain_frame", frame, def.id, kind)
	_append_ext(parts, "intel.stats.chain_patch", patch, def.id, kind)
	var chain: String = SEP.join(parts)
	return IntelRow.new(
		def.id, Strings.get_text("upgrade." + def.id), format_value(kind, stat_of(world.stats, def.id)), chain
	)


static func _append_ext(parts: PackedStringArray, key: String, ext: ExternalMults, id: String, kind: int) -> void:
	var m: float = ext.mult_for(id)
	var a: float = ext.add_for(id)
	if a != 0.0:
		parts.append(_token(key, ("+" if a > 0.0 else "") + _delta(kind, a)))
	if not is_equal_approx(m, 1.0):
		parts.append(_token(key, NumberFormat.format_mult(m)))


static func _delta(kind: int, v: float) -> String:
	if kind == Kind.PCT:
		return NumberFormat.format_percent(v)
	return num(v)


static func _dps_row(s: StatBlock) -> IntelRow:
	var chance: float = clampf(s.crit_chance, 0.0, 1.0)
	var crit_avg: float = 1.0 + chance * maxf(s.crit_mult - 1.0, 0.0)
	return IntelRow.new(
		"dps",
		Strings.get_text("intel.stats.dps"),
		num(dps_of(s)),
		Strings.fill1("intel.stats.chain_dps", "v", NumberFormat.format_mult(crit_avg))
	)


static func _yield_row(s: StatBlock, patch: ExternalMults) -> IntelRow:
	var chain: String = Strings.get_text("intel.stats.chain_none")
	if not is_equal_approx(patch.data_yield_mult, 1.0):
		chain = _token("intel.stats.chain_patch", NumberFormat.format_mult(patch.data_yield_mult))
	return IntelRow.new(
		"data_yield", Strings.get_text("intel.stats.data_yield"), NumberFormat.format_mult(s.data_yield), chain
	)


static func _token(key: String, v: String) -> String:
	return Strings.fill1(key, "v", v)
