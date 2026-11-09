class_name ModeRules
extends RefCounted
## Wave mode rules (M4-07, mirrors FrameRules). Pure static: unlocks at banking and on load, and the card model
## of the Home mode picker. A mode unlocks when the TIMED best wave (sector 1, Q71) reaches the def's
## `unlock_best_timed_wave`; unlocks are permanent (stored in `modes_unlocked`, a later threshold change never
## re-locks). PURGE runs never unlock anything and never raise the TIMED record.
##
## Public API:
##   static load_defs() -> Array[WaveModeDef]              (generated table, CSV order)
##   static find_def(defs, id) -> WaveModeDef              (null when unknown)
##   static unlockable(defs, timed_best) -> Array[String]  (implemented modes the best wave qualifies for)
##   static apply_unlocks(profile, defs) -> Array[String]  (newly unlocked ids; a second call returns [])
##   static cards(profile, defs) -> Array[ModeCard]        (implemented modes, CSV order)

const MODE_TABLE_PATH: String = "res://src/data_gen/wave_mode_table.tres"
const KEY_LOCKED: String = "mode.locked"
const KEY_PROGRESS: String = "mode.progress"


## The wave modes of the generated table in CSV order (shared resources: treat as read-only).
static func load_defs() -> Array[WaveModeDef]:
	var table: WaveModeTable = load(MODE_TABLE_PATH)
	return table.defs


static func find_def(defs: Array[WaveModeDef], id: String) -> WaveModeDef:
	for def: WaveModeDef in defs:
		if def.id == id:
			return def
	return null


## Ids of implemented modes whose threshold is at most `timed_best`, in CSV order.
static func unlockable(defs: Array[WaveModeDef], timed_best: int) -> Array[String]:
	var out: Array[String] = []
	for def: WaveModeDef in defs:
		if def.implemented and def.unlock_best_timed_wave <= timed_best:
			out.append(def.id)
	return out


## Unlocks every mode the profile's TIMED sector 1 best now qualifies for. Returns the ids unlocked by this call.
static func apply_unlocks(profile: PlayerProfile, defs: Array[WaveModeDef]) -> Array[String]:
	var fresh: Array[String] = []
	for id: String in unlockable(defs, profile.best_wave_s1()):
		if profile.unlock_mode(id):
			fresh.append(id)
	return fresh


## One card per implemented mode in CSV order; locked cards carry the lock and progress text.
static func cards(profile: PlayerProfile, defs: Array[WaveModeDef]) -> Array[ModeCard]:
	var out: Array[ModeCard] = []
	var timed_best: int = profile.best_wave_s1()
	for def: WaveModeDef in defs:
		if not def.implemented:
			continue
		var c: ModeCard = ModeCard.new()
		c.id = def.id
		c.name_key = "mode." + def.id
		c.desc_key = "mode." + def.id + ".desc"
		c.unlocked = profile.mode_unlocked(def.id)
		c.unlock_wave = def.unlock_best_timed_wave
		c.best = profile.best_wave_of_mode(def.id, 1)
		c.selected = def.id == profile.last_mode
		if not c.unlocked:
			c.locked_text = Strings.fill1(KEY_LOCKED, "n", str(def.unlock_best_timed_wave))
			c.progress_text = Strings.fill1(KEY_PROGRESS, "n", str(timed_best))
		out.append(c)
	return out
