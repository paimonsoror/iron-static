class_name UpgradePanelModel
extends RefCounted
## Pure state of the upgrade panel (M2-10): active tab, tab filtering by visibility and the
## "next unlock" hint. GDD 07 section 2.1/2.2, 08 section 1.3. INTEL is a stub until M4.

const TAB_IDS: PackedStringArray = ["arms", "chassis", "systems", "intel"]
const TAB_INTEL: String = "intel"

var active_tab: String = "arms"


## Returns false (state unchanged) for an unknown tab id.
func set_tab(tab_id: String) -> bool:
	if not TAB_IDS.has(tab_id):
		return false
	active_tab = tab_id
	return true


## Upgrade row indices shown in `tab_id`: table order, visible rows only. Empty for the INTEL stub.
static func rows_for_tab(defs: Array[RunUpgradeDef], visible: PackedByteArray, tab_id: String) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in defs.size():
		if defs[i].tab == tab_id and i < visible.size() and visible[i] != 0:
			var failed: bool = out.push_back(i)
			if failed:
				push_error("UpgradePanelModel: push_back failed")
	return out


## `Next unlock at wave N` for the lowest locked gate, or "" when every row is unlocked.
static func hint_text(defs: Array[RunUpgradeDef], best_wave_s1: int) -> String:
	var nu: Vector2i = UnlockRules.next_unlock(defs, best_wave_s1)
	if nu.x < 0:
		return ""
	return Strings.fill1("panel.next_unlock", "n", str(nu.y))
