class_name FtueTargets
extends RefCounted
## Maps an FTUE beat target (`row:<id>`, `results_foundry`, `foundry_row:<id>`) to the GLOBAL rect of the widget it
## points at (M4-26). Pure lookups over nodes handed in; Rect2() when the widget is missing or hidden.

static var _foundry_ids: PackedStringArray = PackedStringArray()


static func resolve(target: String, panel: UpgradePanel, results: ResultsOverlay, screen: MenuScreen) -> Rect2:
	if target == FtueScript.TARGET_RESULTS_FOUNDRY:
		return results.foundry_rect() if results != null else Rect2()
	if target.begins_with(FtueScript.ROW_PREFIX):
		return panel.pointer_rect(target.substr(FtueScript.ROW_PREFIX.length())) if panel != null else Rect2()
	if target.begins_with(FtueScript.FOUNDRY_PREFIX):
		return foundry_row_rect(screen, target.substr(FtueScript.FOUNDRY_PREFIX.length()))
	return Rect2()


## Rect of the Foundry row of `foundry_id` when `screen` is the Foundry screen (rows follow data/foundry.csv order).
static func foundry_row_rect(screen: MenuScreen, foundry_id: String) -> Rect2:
	var foundry: FoundryScreen = screen as FoundryScreen
	if foundry == null:
		return Rect2()
	if _foundry_ids.is_empty():
		for def: FoundryDef in SimConfigLoader.load_foundry_defs():
			_foundry_ids.append(def.id)
	var i: int = _foundry_ids.find(foundry_id)
	if i < 0 or i >= foundry.row_count():
		return Rect2()
	var row: FoundryRow = foundry.row_at(i)
	return row.get_global_rect() if row.is_visible_in_tree() else Rect2()
