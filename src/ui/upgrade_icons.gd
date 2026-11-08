class_name UpgradeIcons
extends RefCounted
## Maps an upgrade id to its icon art slot (V1-17; slots `icon_<id>` in `assets/art/slots.csv`) and tint.
## (impl) The icon art is already colored (amber glyph on its own chamfered plate, art bible 7.3), so the
## damage-type tint (GDD 07 s2.2) is baked into the art and `tint_for` returns white for known ids; unknown ids
## get the fallback slot, dimmed, so a new upgrade never renders an empty square.

const FALLBACK_SLOT: String = "icon_ic_lock"
const PREFIX: String = "icon_"
const TINT_FALLBACK: Color = Color(1, 1, 1, 0.5)


## Art slot id for `upgrade_id`; the fallback icon when the table has no `icon_<id>` row.
static func slot_for(upgrade_id: String) -> String:
	var slot_id: String = PREFIX + upgrade_id
	if ArtSlots.has(slot_id):
		return slot_id
	return FALLBACK_SLOT


static func is_known(upgrade_id: String) -> bool:
	return ArtSlots.has(PREFIX + upgrade_id)


static func tint_for(upgrade_id: String) -> Color:
	return Color.WHITE if is_known(upgrade_id) else TINT_FALLBACK
