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
var level: int = 0
var level_text: String = ""
var value_text: String = ""
var cost_text: String = ""
var affordable: bool = false
var maxed: bool = false
var milestone_glow: bool = false
var tooltip_text: String = ""
var icon_color: Color = Palette.TEXT_DIM
## Visual tier mark (VT-6): `tier` 0 = no tiers or below the first mark; `mark_text` "" = no chip; `next_text` is
## "NEXT LOOK AT L12" or "TOP MARK" ("" = no tiers); `tier_progress` 0..1 toward the next mark, `tier_top` at the last.
var tier: int = 0
var tier_has: bool = false
var mark_text: String = ""
var next_text: String = ""
var tier_progress: float = 0.0
var tier_top: bool = false


static func from_preview(
	preview: UpgradePreview,
	can_afford: bool,
	lvl: int,
	def: RunUpgradeDef,
	foundry_level: int = 0,
	foundry_f: float = 0.0,
) -> UpgradeRowModel:
	var m: UpgradeRowModel = UpgradeRowModel.new()
	m.index = preview.index
	m.upgrade_id = def.id
	m.tab = def.tab
	m.name_text = upgrade_name(def.id)
	m.level = lvl
	m.level_text = Strings.fill1("row.level", "n", str(lvl))
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
	m._apply_tier(def.id, lvl)
	# The strings CSV holds a literal backslash-n; make it a real line break.
	m.tooltip_text = tooltip_for(def, foundry_level, foundry_f).replace("\\n", "\n")
	return m


## Stat value text by row id.
## Display name of run upgrade `id` (string key "upgrade.<id>"). The one place that builds that key, so the
## string-key scan of the screen folders sees no partial literals (Home, Foundry and the run panel use it).
static func upgrade_name(id: String) -> String:
	return Strings.get_text("upgrade." + id)


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


## Formula text with the numbers of this row (base, per level, milestone, caps) and the Foundry contribution
## (`foundry_level` F and Type D factor `foundry_f`; F0 shows `tooltip.foundry_none`).
static func tooltip_for(def: RunUpgradeDef, foundry_level: int = 0, foundry_f: float = 0.0) -> String:
	var foundry: String = foundry_text(def, foundry_level, foundry_f)
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
				"step": _delta_text(def, def.step),
				"cap": str(def.l_cap),
				"limit": limit,
				"foundry": foundry,
			}
		)
	)


static func _delta_text(def: RunUpgradeDef, step: float) -> String:
	var sign_text: String = "+" if step >= 0.0 else ""
	if PERCENT_IDS.has(def.id):
		return sign_text + NumberFormat.format_float(step * 100.0, 2) + "%"
	if PERCENT2_IDS.has(def.id):
		return sign_text + NumberFormat.format_float(step * 100.0, 3) + "%"
	return sign_text + NumberFormat.format_float(step, 3)


## "F12  x1.25" (Type D: the Foundry multiplier) or "F12  +0.36" (Type C: the starting stat gain); F0 is `--`.
static func foundry_text(def: RunUpgradeDef, f_level: int, f: float) -> String:
	if f_level <= 0:
		return Strings.get_text("tooltip.foundry_none")
	var lead: String = Strings.fill1("foundry.level", "n", str(f_level))
	if def.kind == "D":
		return lead + "  " + NumberFormat.format_mult(Curves.foundry_mult(f_level, f))
	return lead + "  " + _delta_text(def, def.step * float(f_level))


## Fills the VT-6 mark fields for run upgrade `id` at `lvl` (no-op for rows without visual tiers).
func _apply_tier(id: String, lvl: int) -> void:
	var tiers: VisualTierModel = VisualTierModel.shared()
	if not tiers.has_tiers(id):
		return
	tier_has = true
	tier = tiers.tier_for(id, lvl)
	var key: String = tiers.mark_key(id, lvl)
	mark_text = "" if key.is_empty() else Strings.get_text(key)
	var next: int = tiers.next_threshold(id, lvl)
	tier_top = next < 0
	tier_progress = tiers.progress(id, lvl)
	next_text = Strings.get_text("vt.top") if tier_top else Strings.fill1("vt.next", "n", str(next))
