class_name StatBlock
extends RefCounted
## Final stat values the sim reads (M1 shared contract). `from_base` gives level-0 values; `from_resolver`
## (M2-03) resolves levels, Foundry and external multipliers through StatResolver.

var laser_output: float = 0.0
var cycle_rate: float = 0.0
var crit_chance: float = 0.0
var crit_mult: float = 0.0
var optic_range: float = 0.0
var hull_integrity: float = 0.0
var nano_repair: float = 0.0
var plating_pct: float = 0.0
var plating_flat: float = 0.0
## Extra rows (impl): read by the M2 economy, unused by the M1 sim.
var scrap_yield: float = 0.0
var reinvest: float = 0.0
## Patch-only stats (M4-14), neutral 1.0: multiplier on kill `data` and on enemy damage dealt to Cinder.
var data_yield: float = 1.0
var enemy_damage: float = 1.0


## Level-0 `base` of every run upgrade row in `cfg.upgrades`; `plating_flat` is 0.
static func from_base(cfg: SimConfig) -> StatBlock:
	var s: StatBlock = StatBlock.new()
	for def: RunUpgradeDef in cfg.upgrades:
		s.set_stat(def.id, def.base)
	return s


## Resolved stats from run levels, Foundry levels and external multipliers (M2-03). Empty Foundry arrays = 0.
static func from_resolver(
	defs: Array[RunUpgradeDef],
	run_levels: PackedInt32Array,
	foundry_levels: PackedInt32Array = PackedInt32Array(),
	foundry_f: PackedFloat64Array = PackedFloat64Array(),
	mults: ExternalMults = null,
	tuning: SimTuning = null
) -> StatBlock:
	return StatResolver.resolve(defs, run_levels, foundry_levels, foundry_f, mults, tuning)


## Sets the field named by an upgrade row id; unknown ids are ignored.
func set_stat(id: String, value: float) -> void:
	match id:
		"laser_output":
			laser_output = value
		"cycle_rate":
			cycle_rate = value
		"crit_chance":
			crit_chance = value
		"crit_mult":
			crit_mult = value
		"optic_range":
			optic_range = value
		"hull_integrity":
			hull_integrity = value
		"nano_repair":
			nano_repair = value
		"plating_pct":
			plating_pct = value
		"scrap_yield":
			scrap_yield = value
		"reinvest":
			reinvest = value
