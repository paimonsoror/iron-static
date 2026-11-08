class_name SimConfigLoader
extends RefCounted
## Builds a SimConfig from the generated resources in src/data_gen/. Lives outside src/sim because it
## calls load(). Each call returns private copies, so a caller (a test forcing alive_cap_normal, say)
## can mutate its config without touching the shared, cached resources.

const TUNING_PATH: String = "res://src/data_gen/sim_tuning.tres"
const ENEMY_TABLE_PATH: String = "res://src/data_gen/enemy_table.tres"
const UPGRADE_TABLE_PATH: String = "res://src/data_gen/upgrade_table.tres"
const FOUNDRY_TABLE_PATH: String = "res://src/data_gen/foundry_table.tres"
const FRAME_TABLE_PATH: String = "res://src/data_gen/frame_table.tres"


## Default M1 config: sector 1, standard ruleset, all enemies and upgrades in CSV row order.
static func load_default(seed_value: int) -> SimConfig:
	var cfg: SimConfig = SimConfig.new()
	cfg.seed_value = seed_value
	var tuning_src: SimTuning = load(TUNING_PATH)
	var tuning_copy: Variant = _clone(tuning_src)
	cfg.tuning = tuning_copy
	var enemy_table: EnemyTable = load(ENEMY_TABLE_PATH)
	for def: EnemyDef in enemy_table.defs:
		var enemy_copy: Variant = _clone(def)
		cfg.enemies.append(enemy_copy)
	var upgrade_table: UpgradeTable = load(UPGRADE_TABLE_PATH)
	for def: RunUpgradeDef in upgrade_table.defs:
		var upgrade_copy: Variant = _clone(def)
		cfg.upgrades.append(upgrade_copy)
	return cfg


## Field-by-field copy of a data resource. kept from before the def vars became `@export`
## (M1-26); Resource.duplicate() would now work too, but this is cheap and behavior-proven.
static func _clone(source: Resource) -> Resource:
	var script: GDScript = source.get_script()
	var copy: Resource = script.new()
	for p: Dictionary in source.get_property_list():
		var usage: int = p["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var prop_name: String = p["name"]
			copy.set(prop_name, source.get(prop_name))
	return copy


## The Foundry rows from the generated table (private copies), in display order (M3-06).
static func load_foundry_defs() -> Array[FoundryDef]:
	var out: Array[FoundryDef] = []
	var table: FoundryTable = load(FOUNDRY_TABLE_PATH)
	for def: FoundryDef in table.defs:
		var copy: Variant = _clone(def)
		out.append(copy)
	return out


## Fills `cfg.foundry_levels` / `cfg.foundry_f` aligned with `cfg.upgrades` from a profile's
## `{row id: level}` map (levels clamped to 0..cap, 0 for rows without a Foundry row). All-zero levels
## leave every hash unchanged (ConfigHash only writes non-zero levels).
static func apply_foundry(cfg: SimConfig, profile_levels: Dictionary) -> void:
	var defs: Array[FoundryDef] = load_foundry_defs()
	cfg.foundry_levels = FoundryRules.aligned_levels(cfg.upgrades, defs, profile_levels)
	cfg.foundry_f = FoundryRules.aligned_f(cfg.upgrades, defs)


## Builds `cfg.frame` / `cfg.frame_id` from a frames.csv row (M3-21). Unknown id: push_error, config
## untouched, returns false. Rows with `implemented = false` are applied as data; SimWorld rejects them.
static func apply_frame(cfg: SimConfig, frame_id: String) -> bool:
	var table: FrameTable = load(FRAME_TABLE_PATH)
	for def: FrameDef in table.defs:
		if def.id == frame_id:
			cfg.frame = frame_mods_from(def)
			cfg.frame_id = def.id
			return true
	push_error("SimConfigLoader: unknown frame id '%s'" % frame_id)
	return false


static func frame_mods_from(def: FrameDef) -> FrameMods:
	var m: FrameMods = FrameMods.new()
	m.hull_mult = def.hull_mult
	m.plating_add = def.plating_add
	m.nano_mult = def.nano_mult
	m.cycle_mult = def.cycle_mult
	m.optic_mult = def.optic_mult
	m.laser_mult = def.laser_mult
	m.crit_add = def.crit_add
	m.crit_mult_mult = def.crit_mult_mult
	m.scrap_mult = def.scrap_mult
	m.data_mult = def.data_mult
	m.implemented = def.implemented
	match def.passive:
		"bastion":
			m.passive = FrameMods.PASSIVE_BASTION
		"overclock":
			m.passive = FrameMods.PASSIVE_OVERCLOCK
		"scrap_tithe":
			m.passive = FrameMods.PASSIVE_SCRAP_TITHE
		"first_sight":
			m.passive = FrameMods.PASSIVE_FIRST_SIGHT
		_:
			m.passive = FrameMods.PASSIVE_NONE
	return m
