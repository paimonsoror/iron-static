class_name SimConfigLoader
extends RefCounted
## Builds a SimConfig from the generated resources in src/data_gen/. Lives outside src/sim because it
## calls load(). Each call returns private copies, so a caller (a test forcing alive_cap_normal, say)
## can mutate its config without touching the shared, cached resources.

const TUNING_PATH: String = "res://src/data_gen/sim_tuning.tres"
const ENEMY_TABLE_PATH: String = "res://src/data_gen/enemy_table.tres"
const UPGRADE_TABLE_PATH: String = "res://src/data_gen/upgrade_table.tres"


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
