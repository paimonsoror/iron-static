class_name DraftModel
extends RefCounted
## Pure text model of the patch draft overlay (07 s2.9, M4-16): the title, one card per offer (gamble cards carry both
## the benefit and the cost line), the picks so far this deployment and whether the "Patches last this deployment"
## note shows (only before the first pick, i.e. on the first draft). Reads the sim, never writes it.

var wave: int = 0
var cards: Array[DraftCardData] = []
var picks: Array[DraftCardData] = []
var show_note: bool = false


static func from_world(world: SimWorld) -> DraftModel:
	var m := DraftModel.new()
	m.wave = world.draft.wave
	var defs: Array[PatchDef] = world.config.patches
	for slot: int in world.draft.offers.size():
		var idx: int = world.draft.offers[slot]
		if idx >= 0 and idx < defs.size():
			m.cards.append(DraftCardData.from_def(defs[idx], idx, slot, world.patches.qty(idx)))
	for idx: int in defs.size():
		var q: int = world.patches.qty(idx)
		if q > 0:
			m.picks.append(DraftCardData.from_def(defs[idx], idx, -1, q))
	m.show_note = world.patches.total_picks == 0
	return m


func title() -> String:
	return Strings.fill1("draft.title", "n", str(wave))


## "PICKS: OVERCHARGE 2/5, PLATING 1/5", or "" before the first pick.
func picks_line() -> String:
	if picks.is_empty():
		return ""
	var parts := PackedStringArray()
	for p: DraftCardData in picks:
		parts.append(p.progress_text())
	return Strings.fill1("draft.picks", "list", ", ".join(parts))


func note() -> String:
	return Strings.get_text("draft.note") if show_note else ""
