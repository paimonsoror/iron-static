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
## Non-row stats (M4-14): kill `data` yield and enemy damage (patches only).
var data_yield_mult: float = 1.0
var enemy_damage_mult: float = 1.0

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


## Field-by-field copy.
func copy() -> ExternalMults:
	var c: ExternalMults = ExternalMults.new()
	for p: Dictionary in get_property_list():
		var usage: int = p["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var prop_name: String = p["name"]
			c.set(prop_name, get(prop_name))
	return c


## Multiplies the multiplier of stat `id` by `factor` (unknown ids are ignored).
func scale_stat(id: String, factor: float) -> void:
	match id:
		"laser_output":
			laser_output_mult *= factor
		"cycle_rate":
			cycle_rate_mult *= factor
		"crit_chance":
			crit_chance_mult *= factor
		"crit_mult":
			crit_mult_mult *= factor
		"optic_range":
			optic_range_mult *= factor
		"hull_integrity":
			hull_integrity_mult *= factor
		"nano_repair":
			nano_repair_mult *= factor
		"plating_pct":
			plating_pct_mult *= factor
		"scrap_yield":
			scrap_yield_mult *= factor
		"reinvest":
			reinvest_mult *= factor
		"data_yield":
			data_yield_mult *= factor
		"enemy_damage":
			enemy_damage_mult *= factor


## Adds `value` to the additive bonus of stat `id` (rows only; other ids are ignored).
func add_stat(id: String, value: float) -> void:
	match id:
		"laser_output":
			laser_output_add += value
		"cycle_rate":
			cycle_rate_add += value
		"crit_chance":
			crit_chance_add += value
		"crit_mult":
			crit_mult_add += value
		"optic_range":
			optic_range_add += value
		"hull_integrity":
			hull_integrity_add += value
		"nano_repair":
			nano_repair_add += value
		"plating_pct":
			plating_pct_add += value
		"scrap_yield":
			scrap_yield_add += value
		"reinvest":
			reinvest_add += value
