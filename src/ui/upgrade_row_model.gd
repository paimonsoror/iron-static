class_name UpgradeRowModel
extends RefCounted
## Pure presentation model of one upgrade row (M2-09; GDD 07 section 2.2): texts and states from an
## `UpgradePreview`. No nodes; `UpgradeRow` only copies these fields into labels.
## Value styles per row id (impl): percent rows show %, multiplier rows xN, range in m, others plain numbers.

const MILESTONE_GLOW_LEVELS: int = 3
const PERCENT_IDS: PackedStringArray = ["crit_chance", "plating_pct"]
const PERCENT2_IDS: PackedStringArray = ["reinvest"]
const MULT_IDS: PackedStringArray = ["crit_mult", "scrap_yield"]
const TAB_ICON_COLORS: Dictionary[String, Color] = {
	"arms": Palette.LASER_CORE,
	"chassis": Palette.KINETIC,
	"systems": Palette.SCRAP,
}

var index: int = -1
var upgrade_id: String = ""
var tab: String = ""
var name_text: String = ""
var level_text: String = ""
var value_text: String = ""
var cost_text: String = ""
var affordable: bool = false
var maxed: bool = false
var milestone_glow: bool = false
var tooltip_text: String = ""
var icon_color: Color = Palette.TEXT_DIM


static func from_preview(preview: UpgradePreview, can_afford: bool, level: int, def: RunUpgradeDef) -> UpgradeRowModel:
	var m: UpgradeRowModel = UpgradeRowModel.new()
	m.index = preview.index
	m.upgrade_id = def.id
	m.tab = def.tab
	m.name_text = Strings.get_text("upgrade." + def.id)
	m.level_text = Strings.fill1("row.level", "n", str(level))
	m.maxed = preview.maxed
	m.affordable = can_afford and not preview.maxed
	m.milestone_glow = not preview.maxed and preview.levels_to_milestone <= MILESTONE_GLOW_LEVELS
	m.icon_color = TAB_ICON_COLORS.get(def.tab, Palette.TEXT_DIM)
	var cur: String = format_value(def.id, preview.current_value)
	if preview.maxed:
		m.value_text = cur
		m.cost_text = Strings.get_text("row.max")
	else:
		var nxt: String = format_value(def.id, preview.next_value)
		m.value_text = Strings.fill("row.value", {"a": cur, "b": nxt})
		m.cost_text = NumberFormat.format(preview.cost)
	m.tooltip_text = tooltip_for(def)
	return m


## Stat value text by row id.
static func format_value(id: String, v: float) -> String:
	if PERCENT_IDS.has(id):
		return NumberFormat.format_percent(v)
	if PERCENT2_IDS.has(id):
		return NumberFormat.format_float(v * 100.0, 2) + "%"
	if MULT_IDS.has(id):
		return NumberFormat.format_mult(v)
	if id == "cycle_rate":
		return NumberFormat.format_float(v, 2)
	if id == "optic_range":
		return NumberFormat.format_float(v, 1) + "m"
	if v < 1000.0:
		return NumberFormat.format_float(v, 1)
	return NumberFormat.format(BigNum.from_float(v))


## Formula text with the numbers of this row (base, per level, milestone, caps). Foundry: -- until M3.
static func tooltip_for(def: RunUpgradeDef) -> String:
	var foundry: String = Strings.get_text("tooltip.foundry_none")
	if def.kind == "D":
		return (
			Strings
			. fill(
				"tooltip.d",
				{
					"base": format_value(def.id, def.base),
					"step": NumberFormat.format_float(def.step * 100.0, 0) + "%",
					"cap": str(def.l_cap),
					"foundry": foundry,
				}
			)
		)
	var limit: String = Strings.get_text("tooltip.none")
	if def.has_hard_cap:
		limit = format_value(def.id, def.hard_cap)
	return (
		Strings
		. fill(
			"tooltip.c",
			{
				"base": format_value(def.id, def.base),
				"step": _delta_text(def),
				"cap": str(def.l_cap),
				"limit": limit,
				"foundry": foundry,
			}
		)
	)


static func _delta_text(def: RunUpgradeDef) -> String:
	var sign_text: String = "+" if def.step >= 0.0 else ""
	if PERCENT_IDS.has(def.id):
		return sign_text + NumberFormat.format_float(def.step * 100.0, 2) + "%"
	if PERCENT2_IDS.has(def.id):
		return sign_text + NumberFormat.format_float(def.step * 100.0, 3) + "%"
	return sign_text + NumberFormat.format_float(def.step, 3)
