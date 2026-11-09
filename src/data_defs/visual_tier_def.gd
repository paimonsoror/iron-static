class_name VisualTierDef
extends Resource
## One (upgrade, tier) row of data/visual_tiers.csv (VT-1, docs/design/12). Generated; never hand-edit the .tres.
## `params` is the raw `key=value;key=value` text; read numbers with `param()`.

@export var id: String = ""
@export var upgrade: String = ""
@export var tier: int = 1
@export var mark: String = ""  ## display default; the UI shows `label_key`
@export var threshold_kind: String = "level"
@export var threshold: int = 0
@export var label_key: String = ""
@export var banner_key: String = ""
@export var art_slot: String = "-"
@export var params: String = ""


## Numeric param `key`, or `fallback` when absent or not a number (unknown keys are simply never asked for).
func param(key: String, fallback: float = 0.0) -> float:
	for kv: String in params.split(";", false):
		var pair: PackedStringArray = kv.split("=")
		if pair.size() == 2 and pair[0] == key and pair[1].is_valid_float():
			return pair[1].to_float()
	return fallback
