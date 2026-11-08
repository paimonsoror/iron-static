class_name StatBlock
extends RefCounted
## Final stat values the sim reads (M1 shared contract). M1 fills level-0 base values from the run upgrade
## rows; M2 replaces `from_base` with StatResolver but keeps this interface.

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


## Level-0 `base` of every run upgrade row in `cfg.upgrades`; `plating_flat` is 0.
static func from_base(cfg: SimConfig) -> StatBlock:
	var s: StatBlock = StatBlock.new()
	for def: RunUpgradeDef in cfg.upgrades:
		match def.id:
			"laser_output":
				s.laser_output = def.base
			"cycle_rate":
				s.cycle_rate = def.base
			"crit_chance":
				s.crit_chance = def.base
			"crit_mult":
				s.crit_mult = def.base
			"optic_range":
				s.optic_range = def.base
			"hull_integrity":
				s.hull_integrity = def.base
			"nano_repair":
				s.nano_repair = def.base
			"plating_pct":
				s.plating_pct = def.base
			"scrap_yield":
				s.scrap_yield = def.base
			"reinvest":
				s.reinvest = def.base
	return s
