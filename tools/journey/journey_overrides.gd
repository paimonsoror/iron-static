class_name JourneyOverrides
extends RefCounted
## In-memory balance overrides for the journey tool (FO-2): measure a candidate change without touching data/*.csv.
## Each entry is `key=number` with key one of
##   sim.<SimTuning var>                  e.g. sim.data_level_coef=0.03
##   enemy.<enemy id>.data_base           e.g. enemy.skitter.data_base=0.8
##   enemies.data_scale                   multiplies every enemy data_base
##   foundry.<row id>.<f|f_cap|fc0|fg>    e.g. foundry.laser_output.fc0=40
## Overrides are applied to the private config and Foundry def copies of each run, never to the shared resources.
## The x1.75-per-25-levels milestone is a code constant (Curves), not an override; see the FO-2 and FO-3 reports.

var entries: Array[Dictionary] = []  # {scope, a, b, value}
var error: String = ""


static func parse(specs: PackedStringArray) -> JourneyOverrides:
	var out: JourneyOverrides = JourneyOverrides.new()
	for spec: String in specs:
		var key: String = spec.get_slice("=", 0).strip_edges()
		var value: float = spec.get_slice("=", 1).to_float()
		var parts: PackedStringArray = key.split(".")
		var entry: Dictionary = {"scope": parts[0], "a": "", "b": "", "value": value}
		var ok: bool = false
		if parts[0] == "sim" and parts.size() == 2:
			entry["a"] = parts[1]
			ok = true
		elif parts[0] == "enemies" and parts.size() == 2 and parts[1] == "data_scale":
			entry["a"] = parts[1]
			ok = true
		elif parts[0] == "enemy" and parts.size() == 3 and parts[2] == "data_base":
			entry["a"] = parts[1]
			entry["b"] = parts[2]
			ok = true
		elif parts[0] == "foundry" and parts.size() == 3 and ["f", "f_cap", "fc0", "fg"].has(parts[2]):
			entry["a"] = parts[1]
			entry["b"] = parts[2]
			ok = true
		if not ok:
			out.error = "bad --set key '%s'" % key
			return out
		out.entries.append(entry)
	out.error = out._validate()
	return out


func is_empty() -> bool:
	return entries.is_empty()


func describe() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for e: Dictionary in entries:
		var key: String = "%s.%s" % [e["scope"], e["a"]]
		var tail: String = e["b"]
		if not tail.is_empty():
			key += ".%s" % tail
		if parts.append("%s=%s" % [key, e["value"]]):
			push_error("JourneyOverrides: append failed")
	return " ".join(parts)


## Foundry defs with the foundry.* overrides applied (private copies).
func foundry_defs() -> Array[FoundryDef]:
	var defs: Array[FoundryDef] = SimConfigLoader.load_foundry_defs()
	for e: Dictionary in entries:
		var scope: String = e["scope"]
		if scope != "foundry":
			continue
		var row_id: String = e["a"]
		var field: String = e["b"]
		var def: FoundryDef = FoundryRules.find_def(defs, row_id)
		var value: float = e["value"]
		match field:
			"f":
				def.f = value
			"f_cap":
				def.f_cap = int(value)
			"fc0":
				def.fc0 = value
			_:
				def.fg = value
	return defs


## Applies the sim.* and enemy.* overrides to a config (its tuning and enemy copies are private).
func apply_to_config(cfg: SimConfig) -> void:
	for e: Dictionary in entries:
		var value: float = e["value"]
		var scope: String = e["scope"]
		var key: String = e["a"]
		match scope:
			"sim":
				var current: Variant = cfg.tuning.get(key)
				cfg.tuning.set(key, int(value) if current is int else value)
			"enemies":
				for def: EnemyDef in cfg.enemies:
					def.data_base *= value
			"enemy":
				for def: EnemyDef in cfg.enemies:
					if def.id == key:
						def.data_base = value


func _validate() -> String:
	var tuning: SimTuning = SimTuning.new()
	var enemy_ids: PackedStringArray = PackedStringArray()
	for def: EnemyDef in SimConfigLoader.load_default(0).enemies:
		if enemy_ids.append(def.id):
			return "append failed"
	var defs: Array[FoundryDef] = SimConfigLoader.load_foundry_defs()
	for e: Dictionary in entries:
		var scope: String = e["scope"]
		var key: String = e["a"]
		match scope:
			"sim":
				if tuning.get(key) == null:
					return "unknown sim key '%s'" % key
			"enemy":
				if not enemy_ids.has(key):
					return "unknown enemy id '%s'" % key
			"foundry":
				if FoundryRules.find_def(defs, key) == null:
					return "unknown Foundry id '%s'" % key
	return ""
