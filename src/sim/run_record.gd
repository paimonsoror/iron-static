class_name RunRecord
extends RefCounted
## One recorded run: everything needed to replay it (`Replay.run`) plus the outcome for checking.
## JSON shape (human-readable, compact): {"format":1,"seed":int,"sim_version":int,"config_hash":str,
## "sector":int,"best_wave_s1":int,"ruleset":str,"debug_invulnerable":bool,"final_tick":int,
## "death_wave":int,"final_hash":str,"command_count":int,"commands":"dt,a,b;dt,a,b[,kind];..."}.
## Commands are one string: ticks are deltas from the previous command; the kind is omitted for CMD_BUY (0)
## and appended as a fourth field otherwise. About 7 bytes per buy, so 2,000 commands are about 14 KB.
## Optional keys (M3, absent = pre-M3 behavior): "foundry":"id:level;id:level" (id-keyed, only non-zero levels, row
## order of the recording config; absent = all zero) and "frame":"<id>" (absent = vanguard). `apply_to` restores the
## Foundry levels by id; the Foundry factors `f` and the frame modifiers are config data the caller supplies
## (the config hash detects a mismatch).
## Pause menu: optional "ended":"aborted" (absent = the run died): the player aborted at `final_tick`, the world was not
## over, `death_wave` is the wave being played and `final_hash` the hash of that live world. `Replay` stops at
## `final_tick` for such a record (applying the commands due on that tick), so it reproduces `final_hash`.
## M4-05: optional "mode":"purge" (absent = timed). `apply_to` sets `cfg.wave_mode`; the backstop and reward numbers are
## config data like the Foundry factors, so build the config with `SimConfigLoader.apply_mode(cfg, rec.mode)` first.

const FORMAT: int = 1

var seed_value: int = 0
var sim_version: int = SimVersion.CURRENT
var config_hash: String = ""
var sector: int = 1
var best_wave_s1: int = 0
var ruleset: String = "standard"
var debug_invulnerable: bool = false
var foundry: String = ""
var frame_id: String = "vanguard"
var mode: String = SimConfig.MODE_TIMED
var final_tick: int = 0
var death_wave: int = 0
## True when the player aborted the mission (pause menu) instead of dying: the replay stops at `final_tick`.
var aborted: bool = false
var final_hash: String = ""
var commands: InputLog = InputLog.new()


## Snapshot of a world (finished or not): inputs from its config and log, outcome from its state. `aborted`: the
## player ended a live world; its death wave is then the wave being played.
static func from_world(world: SimWorld, was_aborted: bool = false) -> RunRecord:
	var r: RunRecord = RunRecord.new()
	var cfg: SimConfig = world.config
	r.seed_value = cfg.seed_value
	r.config_hash = ConfigHash.compute(cfg)
	r.sector = cfg.sector
	r.best_wave_s1 = cfg.best_wave_s1
	r.ruleset = cfg.ruleset
	r.debug_invulnerable = cfg.debug_invulnerable
	r.foundry = _foundry_text(cfg)
	r.frame_id = cfg.frame_id
	r.mode = cfg.wave_mode
	r.final_tick = world.tick
	r.aborted = was_aborted and not world.is_over()
	r.death_wave = world.wave if r.aborted else world.run.death_wave
	r.final_hash = world.state_hash()
	r.commands = world.input_log
	return r


## Copies the recorded run inputs into `cfg` (tuning, enemies and upgrades stay the caller's).
func apply_to(cfg: SimConfig) -> void:
	cfg.seed_value = seed_value
	cfg.sector = sector
	cfg.best_wave_s1 = best_wave_s1
	cfg.ruleset = ruleset
	cfg.debug_invulnerable = debug_invulnerable
	cfg.wave_mode = mode
	_apply_foundry(cfg)
	if frame_id != cfg.frame_id:
		if frame_id == "vanguard":
			cfg.frame = null
			cfg.frame_id = frame_id
		else:
			push_error("RunRecord: config lacks the modifiers of frame '%s'" % frame_id)


func to_json() -> String:
	var parts: PackedStringArray = PackedStringArray()
	var prev: int = 0
	for i: int in commands.size():
		var t: int = commands.ticks[i]
		var s: String = "%d,%d,%d" % [t - prev, commands.arg_a[i], commands.arg_b[i]]
		if commands.kinds[i] != InputLog.CMD_BUY:
			s += ",%d" % commands.kinds[i]
		if parts.append(s):
			push_error("RunRecord: append failed")
		prev = t
	var d: Dictionary = {
		"format": FORMAT,
		"seed": seed_value,
		"sim_version": sim_version,
		"config_hash": config_hash,
		"sector": sector,
		"best_wave_s1": best_wave_s1,
		"ruleset": ruleset,
		"debug_invulnerable": debug_invulnerable,
		"final_tick": final_tick,
		"death_wave": death_wave,
		"final_hash": final_hash,
		"command_count": commands.size(),
		"commands": ";".join(parts),
	}
	if foundry != "":
		d["foundry"] = foundry
	if frame_id != "vanguard":
		d["frame"] = frame_id
	if mode != SimConfig.MODE_TIMED:
		d["mode"] = mode
	if aborted:
		d["ended"] = "aborted"
	return JSON.stringify(d)


## Parses `to_json` output; returns null on malformed input.
static func from_json(text: String) -> RunRecord:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = parsed
	if _geti(d, "format", 0) != FORMAT:
		return null
	var r: RunRecord = RunRecord.new()
	r.seed_value = _geti(d, "seed", 0)
	r.sim_version = _geti(d, "sim_version", 0)
	r.config_hash = _gets(d, "config_hash", "")
	r.sector = _geti(d, "sector", 1)
	r.best_wave_s1 = _geti(d, "best_wave_s1", 0)
	r.ruleset = _gets(d, "ruleset", "standard")
	r.debug_invulnerable = _getb(d, "debug_invulnerable")
	r.final_tick = _geti(d, "final_tick", 0)
	r.death_wave = _geti(d, "death_wave", 0)
	r.final_hash = _gets(d, "final_hash", "")
	r.foundry = _gets(d, "foundry", "")
	r.frame_id = _gets(d, "frame", "vanguard")
	r.mode = _gets(d, "mode", SimConfig.MODE_TIMED)
	r.aborted = _gets(d, "ended", "") == "aborted"
	var packed: String = _gets(d, "commands", "")
	var t: int = 0
	if packed != "":
		for token: String in packed.split(";"):
			var f: PackedStringArray = token.split(",")
			if f.size() < 3 or f.size() > 4:
				return null
			t += int(f[0])
			r.commands.append(t, int(f[3]) if f.size() == 4 else InputLog.CMD_BUY, int(f[1]), int(f[2]))
	if r.commands.size() != _geti(d, "command_count", r.commands.size()):
		return null
	return r


static func _geti(d: Dictionary, key: String, fallback: int) -> int:
	var v: Variant = d.get(key, fallback)
	if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
		var n: float = v
		return int(n)
	return fallback


static func _getb(d: Dictionary, key: String) -> bool:
	var v: Variant = d.get(key, false)
	return typeof(v) == TYPE_BOOL and v == true


static func _gets(d: Dictionary, key: String, fallback: String) -> String:
	var v: Variant = d.get(key, fallback)
	return v if typeof(v) == TYPE_STRING else fallback


static func _foundry_text(cfg: SimConfig) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for i: int in mini(cfg.foundry_levels.size(), cfg.upgrades.size()):
		if cfg.foundry_levels[i] != 0:
			if parts.append("%s:%d" % [cfg.upgrades[i].id, cfg.foundry_levels[i]]):
				push_error("RunRecord: append failed")
	return ";".join(parts)


## Sets `cfg.foundry_levels` from the record (empty when none), keeping `foundry_f` when it is already aligned.
## Ids the config does not know are ignored; the config hash then differs and the replay is flagged.
func _apply_foundry(cfg: SimConfig) -> void:
	cfg.foundry_levels = PackedInt32Array()
	if foundry == "":
		return
	if cfg.foundry_levels.resize(cfg.upgrades.size()) != OK:
		push_error("RunRecord: resize failed")
	cfg.foundry_levels.fill(0)
	if cfg.foundry_f.size() != cfg.upgrades.size():
		var f: PackedFloat64Array = PackedFloat64Array()
		if f.resize(cfg.upgrades.size()) != OK:
			push_error("RunRecord: resize failed")
		f.fill(0.0)
		cfg.foundry_f = f
	for token: String in foundry.split(";"):
		var kv: PackedStringArray = token.split(":")
		if kv.size() != 2:
			continue
		for i: int in cfg.upgrades.size():
			if cfg.upgrades[i].id == kv[0]:
				cfg.foundry_levels[i] = maxi(0, int(kv[1]))
