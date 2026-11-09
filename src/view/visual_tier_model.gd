class_name VisualTierModel
extends RefCounted
## Pure lookup of the upgrade visual tiers (VT-1, docs/design/12): which mark an upgrade row shows at a run level,
## where the next one is and how far along. Reads only the `VisualTierDef` table and the level passed in; no sim,
## no nodes. Tier 0 = below the first mark (only plating has no mark at L0); tiers run 1 to `max_tier`.

const TABLE_PATH: String = "res://src/data_gen/visual_tier_table.tres"

static var _default: VisualTierModel = null

var _by_stat: Dictionary = {}  # upgrade id -> Array[VisualTierDef], tier order


func _init(defs: Array[VisualTierDef] = []) -> void:
	for def: VisualTierDef in defs:
		if not _by_stat.has(def.upgrade):
			var list: Array[VisualTierDef] = []
			_by_stat[def.upgrade] = list
		var tiers: Array[VisualTierDef] = _by_stat[def.upgrade]
		tiers.append(def)


## The shared model over the generated table (loaded once).
static func shared() -> VisualTierModel:
	if _default == null:
		var table: VisualTierTable = load(TABLE_PATH)
		_default = VisualTierModel.new(table.defs)
	return _default


func has_tiers(stat: String) -> bool:
	return _by_stat.has(stat)


## Number of tiers of `stat` (0 when it has none).
func max_tier(stat: String) -> int:
	if not _by_stat.has(stat):
		return 0
	var tiers: Array[VisualTierDef] = _by_stat[stat]
	return tiers.size()


## Tier reached at run level `level`: 0 below the first threshold, else 1 to `max_tier`.
func tier_for(stat: String, level: int) -> int:
	if not _by_stat.has(stat):
		return 0
	var tiers: Array[VisualTierDef] = _by_stat[stat]
	var reached: int = 0
	for i: int in tiers.size():
		if level >= tiers[i].threshold:
			reached = i + 1
	return reached


## The def of the tier reached at `level`, or null (no tiers, or below the first mark).
func def_for(stat: String, level: int) -> VisualTierDef:
	var tier: int = tier_for(stat, level)
	if tier == 0:
		return null
	var tiers: Array[VisualTierDef] = _by_stat[stat]
	return tiers[tier - 1]


## String key of the mark shown at `level` ("" below the first mark).
func mark_key(stat: String, level: int) -> String:
	var def: VisualTierDef = def_for(stat, level)
	return "" if def == null else def.label_key


## Level of the next tier, or -1 when `stat` has no tiers or `level` is at the top mark.
func next_threshold(stat: String, level: int) -> int:
	if not _by_stat.has(stat):
		return -1
	var tiers: Array[VisualTierDef] = _by_stat[stat]
	var tier: int = tier_for(stat, level)
	if tier >= tiers.size():
		return -1
	return tiers[tier].threshold


## Progress 0..1 from the current tier's threshold (0 below the first mark) to the next one; 1.0 at the top mark
## and for stats without tiers.
func progress(stat: String, level: int) -> float:
	var next: int = next_threshold(stat, level)
	if next < 0:
		return 1.0
	var def: VisualTierDef = def_for(stat, level)
	var from: int = 0 if def == null else def.threshold
	return clampf(float(level - from) / float(next - from), 0.0, 1.0)
