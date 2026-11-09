class_name DraftCardData
extends RefCounted
## One patch as the draft overlay shows it (M4-16): texts resolved through data/strings_en.csv, no numbers of its
## own (the benefit and cost texts carry them). Pure.

var slot: int = 0  ## position among the offers (the argument of `command_pick`)
var patch_index: int = -1  ## row of `SimConfig.patches`
var id: String = ""
var title: String = ""
var benefit: String = ""
var cost_line: String = ""  ## "" for a standard patch, "COST: HULL INTEGRITY x0.5" for a gamble
var gamble: bool = false
var qty: int = 0  ## picks of this patch so far this deployment
var max_picks: int = 0


static func from_def(def: PatchDef, index: int, slot_index: int, picked: int) -> DraftCardData:
	var d := DraftCardData.new()
	d.slot = slot_index
	d.patch_index = index
	d.id = def.id
	d.title = Strings.get_text(def.name_key)
	d.benefit = Strings.get_text(def.desc_key)
	d.gamble = def.is_gamble()
	if d.gamble:
		d.cost_line = Strings.fill1("patch.cost_line", "cost", Strings.get_text(_cost_key(def)))
	d.qty = picked
	d.max_picks = def.max_picks
	return d


## "OVERCHARGE 2/5".
func progress_text() -> String:
	return "%s %d/%d" % [title, qty, max_picks]


## The cost string key of a gamble patch: `patch.<name>.cost` next to its name key (patch.t_greed.name).
static func _cost_key(def: PatchDef) -> String:
	return def.name_key.trim_suffix(".name") + ".cost"
