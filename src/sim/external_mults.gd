class_name ExternalMults
extends RefCounted
## External per-stat modifiers (firmware, Lab, patches; supplied from M3). Defaults are neutral:
## `<stat>_mult` = 1.0, `<stat>_add` = 0.0. Multipliers apply after the Type D product or after the Type C
## clamp; additive bonuses apply after the Type D product and before the Type C clamp (impl).

var laser_output_mult: float = 1.0
var cycle_rate_mult: float = 1.0
var crit_chance_mult: float = 1.0
var crit_mult_mult: float = 1.0
var optic_range_mult: float = 1.0
var hull_integrity_mult: float = 1.0
var nano_repair_mult: float = 1.0
var plating_pct_mult: float = 1.0
var scrap_yield_mult: float = 1.0
var reinvest_mult: float = 1.0

var laser_output_add: float = 0.0
var cycle_rate_add: float = 0.0
var crit_chance_add: float = 0.0
var crit_mult_add: float = 0.0
var optic_range_add: float = 0.0
var hull_integrity_add: float = 0.0
var nano_repair_add: float = 0.0
var plating_pct_add: float = 0.0
var scrap_yield_add: float = 0.0
var reinvest_add: float = 0.0


## Multiplier for an upgrade row id (1.0 for unknown ids).
func mult_for(id: String) -> float:
	var v: float = 1.0
	match id:
		"laser_output":
			v = laser_output_mult
		"cycle_rate":
			v = cycle_rate_mult
		"crit_chance":
			v = crit_chance_mult
		"crit_mult":
			v = crit_mult_mult
		"optic_range":
			v = optic_range_mult
		"hull_integrity":
			v = hull_integrity_mult
		"nano_repair":
			v = nano_repair_mult
		"plating_pct":
			v = plating_pct_mult
		"scrap_yield":
			v = scrap_yield_mult
		"reinvest":
			v = reinvest_mult
	return v


## Additive bonus for an upgrade row id (0.0 for unknown ids).
func add_for(id: String) -> float:
	var v: float = 0.0
	match id:
		"laser_output":
			v = laser_output_add
		"cycle_rate":
			v = cycle_rate_add
		"crit_chance":
			v = crit_chance_add
		"crit_mult":
			v = crit_mult_add
		"optic_range":
			v = optic_range_add
		"hull_integrity":
			v = hull_integrity_add
		"nano_repair":
			v = nano_repair_add
		"plating_pct":
			v = plating_pct_add
		"scrap_yield":
			v = scrap_yield_add
		"reinvest":
			v = reinvest_add
	return v
