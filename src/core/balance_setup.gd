class_name BalanceSetup
extends RefCounted
## Shared config building for the headless tools (tools/balance_run.gd, tools/sim_run.gd; M3-08, M3-24):
## Foundry level specs, frame validation and the SimConfig for one run. Lives in src/core (calls load()).


## Parses `id=level,id=level` into `{id: level}`. Empty text gives an empty map. Sets `error` (non-empty)
## on a malformed pair; unknown ids are checked by `foundry_error`.
class FoundrySpec:
	extends RefCounted
	var levels: Dictionary = {}
	var error: String = ""


static func parse_foundry_spec(text: String) -> FoundrySpec:
	var out: FoundrySpec = FoundrySpec.new()
	if text.strip_edges().is_empty():
		return out
	for pair: String in text.split(",", false):
		var parts: PackedStringArray = pair.split("=")
		if parts.size() != 2 or parts[0].strip_edges().is_empty() or not parts[1].strip_edges().is_valid_int():
			out.error = "bad --foundry pair '%s' (use id=level,id=level)" % pair
			return out
		var level: int = parts[1].strip_edges().to_int()
		if level < 0:
			out.error = "--foundry level must be at least 0 ('%s')" % pair
			return out
		out.levels[parts[0].strip_edges()] = level
	return out


## Empty when every id in `levels` is a Foundry row, else a one-line reason.
static func foundry_error(levels: Dictionary) -> String:
	var defs: Array[FoundryDef] = SimConfigLoader.load_foundry_defs()
	for key: Variant in levels.keys():
		if FoundryRules.find_def(defs, str(key)) == null:
			return "unknown Foundry id '%s'" % str(key)
	return ""


## Empty when `frame_id` is an implemented frame in frames.csv, else a one-line reason.
static func frame_error(frame_id: String) -> String:
	var table: FrameTable = load(SimConfigLoader.FRAME_TABLE_PATH)
	for def: FrameDef in table.defs:
		if def.id == frame_id:
			return "" if def.implemented else "frame '%s' is not implemented yet" % frame_id
	return "unknown frame id '%s'" % frame_id


## Ids of the implemented frames in frames.csv order (vanguard first).
static func implemented_frames() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var table: FrameTable = load(SimConfigLoader.FRAME_TABLE_PATH)
	for def: FrameDef in table.defs:
		if def.implemented and out.append(def.id):
			push_error("BalanceSetup: append failed")
	return out


## Total `data` the given Foundry levels cost from level 0 (float, exact below 1e15).
static func foundry_cost(levels: Dictionary) -> float:
	var defs: Array[FoundryDef] = SimConfigLoader.load_foundry_defs()
	var total: float = 0.0
	for def: FoundryDef in defs:
		var raw: Variant = levels.get(def.id, 0)
		var num: float = raw if (raw is int or raw is float) else 0.0
		var lvl: int = int(num)
		total += FoundryRules.total_cost(def, 0, lvl).to_float()
	return total


## The config of one run: sector 1 defaults, best wave, Foundry levels and frame applied.
static func make_config(
	seed_value: int, sector: int, best_wave: int, foundry_levels: Dictionary, frame_id: String
) -> SimConfig:
	var cfg: SimConfig = SimConfigLoader.load_default(seed_value)
	cfg.sector = sector
	cfg.best_wave_s1 = best_wave
	if not foundry_levels.is_empty():
		SimConfigLoader.apply_foundry(cfg, foundry_levels)
	if frame_id != "vanguard":
		if not SimConfigLoader.apply_frame(cfg, frame_id):
			push_error("BalanceSetup: frame '%s' not applied" % frame_id)
	return cfg
