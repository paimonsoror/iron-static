class_name UtTiers
extends RefCounted
## Reader of the visual tier table for the style-frame harness (debug only; was a reader of the proposed CSV, now
## the real generated `VisualTierTable`, VT-1). Rows are `{id, upgrade, tier, mark, kind, threshold, banner,
## params: Dictionary}`; the API of the old reader is kept.

var rows: Array[Dictionary] = []


static func load_default() -> UtTiers:
	var t := UtTiers.new()
	var table: VisualTierTable = load(VisualTierModel.TABLE_PATH)
	for d: VisualTierDef in table.defs:
		var p: Dictionary = {}
		for kv: String in d.params.split(";", false):
			var pair: PackedStringArray = kv.split("=")
			if pair.size() == 2:
				p[pair[0]] = pair[1].to_float()
		(
			t
			. rows
			. append(
				{
					"id": d.id,
					"upgrade": d.upgrade,
					"tier": d.tier,
					"mark": d.mark,
					"kind": d.threshold_kind,
					"threshold": float(d.threshold),
					"banner": d.banner_key,
					"params": p,
				}
			)
		)
	return t


## Params of `upgrade` at `tier` (1-based); empty when missing.
func params(upgrade: String, tier: int) -> Dictionary:
	for r: Dictionary in rows:
		if r["upgrade"] == upgrade and r["tier"] == tier:
			var p: Dictionary = r["params"]
			return p
	return {}


func mark(upgrade: String, tier: int) -> String:
	for r: Dictionary in rows:
		if r["upgrade"] == upgrade and r["tier"] == tier:
			var mk: String = r["mark"]
			return mk
	return ""


## Tier (1-based) reached at `value` (a level); 1 when below every threshold.
func tier_for(upgrade: String, value: float) -> int:
	var best: int = 1
	for r: Dictionary in rows:
		var th: float = r["threshold"]
		var tr: int = r["tier"]
		if r["upgrade"] == upgrade and value >= th:
			best = maxi(best, tr)
	return best
