class_name PatchDef
extends Resource
## One in-run patch row of data/patches.csv (GDD 02 section 10; M4-13). Generated; never hand-edit the .tres.
## `op`: "bonus" = stat x (1 + per_pick x qty), "mult" = stat x per_pick^qty, "add" = stat + per_pick x qty.
## `stat` may name several stats separated by ";" (see `stat_ids`). A gamble row also names its cost
## (`cost_stat`, always a `mult` of `cost_value`), applied once per pick together with the benefit.

@export var id: String = ""
@export var kind: String = "standard"  ## "standard" or "gamble"
@export var stat: String = ""
@export var op: String = "bonus"
@export var per_pick: float = 0.0
@export var max_picks: int = 0
@export var cost_stat: String = ""
@export var cost_op: String = ""
@export var cost_value: float = 1.0
@export var name_key: String = ""
@export var desc_key: String = ""
@export var tag: String = ""


## The stats this patch changes, in CSV order.
func stat_ids() -> PackedStringArray:
	return stat.split(";", false)


func is_gamble() -> bool:
	return kind == "gamble"
