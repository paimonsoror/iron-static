class_name FtueScript
extends RefCounted
## The first-time-user-experience beat list (M4-25, docs/design/07 s3). Pure: wraps the rows of data/ftue.csv
## (generated `FtueTable`, CSV order = the 07 s3 order). A beat has a trigger (an event name), a target (what the
## overlay points at), a one-line text key and `max_runs` (the last run number, 1 or 2, that shows it).
##
## Public API:
##   static load_default() -> FtueScript        (the generated table)
##   beats() / beat(id) / beats_for(trigger)     (CSV order; null for an unknown id)
##   static is_silent(beat) / is_row(beat) / row_id(beat) / foundry_id(beat)

const TABLE_PATH: String = "res://src/data_gen/ftue_table.tres"
## Only the first two runs of a fresh profile show hints.
const MAX_RUNS: int = 2

const COLD_OPEN: String = "cold_open"
const RUN1_START: String = "run1_start"
const FIRST_KILL: String = "first_kill"
const SCRAP_AFFORDS_CYCLE_RATE: String = "scrap_affords_cycle_rate"
const DART_FIRST_SEEN: String = "dart_first_seen"
const FIRST_DAMAGE_TAKEN: String = "first_damage_taken"
const DRAFT_OPEN_FIRST: String = "draft_open_first"
const DEATH_FIRST: String = "death_first"
const RESULTS_FIRST: String = "results_first"
const FOUNDRY_FIRST: String = "foundry_first"
const RUN2_START: String = "run2_start"
const TRIGGERS: PackedStringArray = [
	COLD_OPEN,
	RUN1_START,
	FIRST_KILL,
	SCRAP_AFFORDS_CYCLE_RATE,
	DART_FIRST_SEEN,
	FIRST_DAMAGE_TAKEN,
	DRAFT_OPEN_FIRST,
	DEATH_FIRST,
	RESULTS_FIRST,
	FOUNDRY_FIRST,
	RUN2_START,
]

const TARGET_NONE: String = "none"
const TARGET_DRAFT: String = "draft"
const TARGET_COLD_OPEN: String = "cold_open"
const TARGET_FIELD: String = "field"
const TARGET_RESULTS_FOUNDRY: String = "results_foundry"
const FIXED_TARGETS: PackedStringArray = [
	TARGET_NONE, TARGET_DRAFT, TARGET_COLD_OPEN, TARGET_FIELD, TARGET_RESULTS_FOUNDRY
]
const ROW_PREFIX: String = "row:"
const FOUNDRY_PREFIX: String = "foundry_row:"

## The three amber lines of the cold open (07 s3), in order.
const COLD_LINE_KEYS: PackedStringArray = ["ftue.cold.1", "ftue.cold.2", "ftue.cold.3"]

var _defs: Array[FtueBeatDef] = []


func _init(defs: Array[FtueBeatDef] = []) -> void:
	_defs = defs


static func load_default() -> FtueScript:
	var table: FtueTable = load(TABLE_PATH)
	return FtueScript.new(table.defs)


func beats() -> Array[FtueBeatDef]:
	return _defs


func beat(id: String) -> FtueBeatDef:
	for def: FtueBeatDef in _defs:
		if def.id == id:
			return def
	return null


## Beats fired by `trigger`, in CSV order.
func beats_for(trigger: String) -> Array[FtueBeatDef]:
	var out: Array[FtueBeatDef] = []
	for def: FtueBeatDef in _defs:
		if def.trigger == trigger:
			out.append(def)
	return out


## Silent beats draw nothing here (the draft overlay and the results screen carry their own text); they complete
## the moment their event fires.
static func is_silent(def: FtueBeatDef) -> bool:
	return def.target == TARGET_NONE or def.target == TARGET_DRAFT


## True when the beat points at a run upgrade row.
static func is_row(def: FtueBeatDef) -> bool:
	return def.target.begins_with(ROW_PREFIX)


## Run upgrade id of a `row:<id>` target, "" otherwise.
static func row_id(def: FtueBeatDef) -> String:
	return def.target.substr(ROW_PREFIX.length()) if is_row(def) else ""


## Foundry id of a `foundry_row:<id>` target, "" otherwise.
static func foundry_id(def: FtueBeatDef) -> String:
	return def.target.substr(FOUNDRY_PREFIX.length()) if def.target.begins_with(FOUNDRY_PREFIX) else ""
