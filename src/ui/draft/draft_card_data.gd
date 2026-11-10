class_name DraftCardData
extends RefCounted
## One patch as the draft overlay shows it (M4-16, I-04 in R1-04): texts resolved through data/strings_en.csv, the
## stat icon slot, the family, the concrete change for this run ("LASER OUTPUT 28.6 > 32.9") and the pick pips. The
## change text needs the world (`from_def` with `world`); without it the card carries the static per-pick text only.
## Pure; reads the sim, never writes it.

## Icon art slot per patch stat that has no run upgrade row of its own (impl, R1-04).
const STAT_ICON_SLOTS: Dictionary[String, String] = {
	"data_yield": "icon_cur_data",
	"enemy_damage": "icon_hull_integrity",
}
## Stats shown as a multiplier (no upgrade row formats them).
const MULT_STATS: PackedStringArray = ["data_yield", "enemy_damage"]

var slot: int = 0  ## position among the offers (the argument of `command_pick`)
var patch_index: int = -1  ## row of `SimConfig.patches`
var id: String = ""
var family: String = "arms"  ## "arms", "chassis" or "systems"
var icon_slot: String = ""  ## art slot of the stat icon
var title: String = ""
var benefit: String = ""  ## the static per-pick text ("LASER OUTPUT +15% PER PICK")
var change_lines: PackedStringArray = PackedStringArray()  ## "LASER OUTPUT 28.6 > 32.9", one per changed stat
var cost_line: String = ""  ## "" for a standard patch, "COST: HULL INTEGRITY 120 > 84" (or "x0.5") for a gamble
var gamble: bool = false
var qty: int = 0  ## picks of this patch so far this deployment
var max_picks: int = 0


static func from_def(def: PatchDef, index: int, slot_index: int, picked: int, world: SimWorld = null) -> DraftCardData:
	var d := DraftCardData.new()
	d.slot = slot_index
	d.patch_index = index
	d.id = def.id
	d.family = def.family
	d.icon_slot = icon_slot_for(def)
	d.title = Strings.get_text(def.name_key)
	d.benefit = Strings.get_text(def.desc_key)
	d.gamble = def.is_gamble()
	d.qty = picked
	d.max_picks = def.max_picks
	var before: StatBlock = null
	var after: StatBlock = null
	if world != null and index >= 0:
		before = stats_after_pick(world, -1)
		after = stats_after_pick(world, index)
	if after != null:
		for s: String in def.stat_ids():
			if d.change_lines.append(change_text(s, before, after)):
				push_error("DraftCardData: append failed")
	if d.change_lines.is_empty() and d.change_lines.append(d.benefit):
		push_error("DraftCardData: append failed")
	if d.gamble:
		var cost_text: String = Strings.get_text(_cost_key(def))
		if after != null:
			cost_text = change_text(def.cost_stat, before, after)
		d.cost_line = Strings.fill1("patch.cost_line", "cost", cost_text)
	return d


## The stats `world` would have after one more pick of patch `index` (-1: none, the current picks); the sim state
## is not touched.
static func stats_after_pick(world: SimWorld, index: int) -> StatBlock:
	var state := PatchState.new()
	state.set_picks(world.patches.picks)
	if index >= 0 and not state.add(index):
		return world.stats
	var ext: ExternalMults = PatchEffects.compose(world.frame_ext, state, world.config.patches)
	return StatBlock.from_resolver(
		world.config.upgrades, world.run_levels, world.config.foundry_levels, world.config.foundry_f, ext
	)


## "LASER OUTPUT 28.6 > 32.9" for stat `stat_id` between two stat blocks.
static func change_text(stat_id: String, before: StatBlock, after: StatBlock) -> String:
	return (
		Strings
		. fill(
			"draft.change",
			{
				"stat": stat_name(stat_id),
				"a": format_stat(stat_id, stat_value(before, stat_id)),
				"b": format_stat(stat_id, stat_value(after, stat_id)),
			}
		)
	)


static func stat_name(stat_id: String) -> String:
	if MULT_STATS.has(stat_id):
		return Strings.get_text("draft.stat." + stat_id)
	return UpgradeRowModel.upgrade_name(stat_id)


static func format_stat(stat_id: String, v: float) -> String:
	if MULT_STATS.has(stat_id):
		return NumberFormat.format_mult(v)
	return UpgradeRowModel.format_value(stat_id, v)


static func stat_value(block: StatBlock, stat_id: String) -> float:
	match stat_id:
		"laser_output":
			return block.laser_output
		"cycle_rate":
			return block.cycle_rate
		"hull_integrity":
			return block.hull_integrity
		"nano_repair":
			return block.nano_repair
		"plating_pct":
			return block.plating_pct
		"scrap_yield":
			return block.scrap_yield
		"data_yield":
			return block.data_yield
		"enemy_damage":
			return block.enemy_damage
		_:
			return 0.0


## Icon art slot of the first stat of `def`: its upgrade icon, or the `STAT_ICON_SLOTS` stand-in.
static func icon_slot_for(def: PatchDef) -> String:
	var stats: PackedStringArray = def.stat_ids()
	var first: String = stats[0] if not stats.is_empty() else ""
	if STAT_ICON_SLOTS.has(first):
		return STAT_ICON_SLOTS[first]
	return UpgradeIcons.slot_for(first)


## Family accent color (amber ARMS, teal CHASSIS, scrap-gold SYSTEMS).
static func family_color(fam: String) -> Color:
	match fam:
		"chassis":
			return Palette.TEAL
		"systems":
			return Palette.SCRAP
		_:
			return Palette.AMBER


## "ARMS" / "CHASSIS" / "SYSTEMS" label.
func family_text() -> String:
	return Strings.get_text("draft.family." + family)


## "OVERCHARGE 2/5".
func progress_text() -> String:
	return "%s %d/%d" % [title, qty, max_picks]


## The cost string key of a gamble patch: `patch.<name>.cost` next to its name key (patch.t_greed.name).
static func _cost_key(def: PatchDef) -> String:
	return def.name_key.trim_suffix(".name") + ".cost"
