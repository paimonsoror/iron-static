class_name UtTiers
extends RefCounted
## Reader of the PROPOSED visual tier table (docs/design/12_upgrade_visual_tiers.md s6) for the style-frame harness.
## Debug only. Rows are `{id, upgrade, tier, mark, kind, threshold, banner, params: Dictionary}`.

const PATH: String = "res://docs/design/style/upgrade_tiers/visual_tiers.proposed.csv"

var rows: Array[Dictionary] = []


static func load_default() -> UtTiers:
	var t := UtTiers.new()
	var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("visual tiers csv missing: " + PATH)
		return t
	var header_seen: bool = false
	while not f.eof_reached():
		var line: String = f.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if not header_seen:
			header_seen = true
			continue
		var c: PackedStringArray = line.split(",")
		if c.size() < 10:
			continue
		var p: Dictionary = {}
		for kv: String in c[9].split(";"):
			var pair: PackedStringArray = kv.split("=")
			if pair.size() == 2:
				p[pair[0]] = pair[1].to_float()
		(
			t
			. rows
			. append(
				{
					"id": c[0],
					"upgrade": c[1],
					"tier": c[2].to_int(),
					"mark": c[3],
					"kind": c[4],
					"threshold": c[5].to_float(),
					"banner": c[7],
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


## Tier (1-based) reached at `value` (a level, or a fraction of the cap for cap_frac rows).
func tier_for(upgrade: String, value: float) -> int:
	var best: int = 1
	for r: Dictionary in rows:
		var th: float = r["threshold"]
		var tr: int = r["tier"]
		if r["upgrade"] == upgrade and value >= th:
			best = maxi(best, tr)
	return best
