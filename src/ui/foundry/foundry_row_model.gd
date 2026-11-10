class_name FoundryRowModel
extends RefCounted
## Pure text model of one Foundry row (M3-16; GDD 05 section 1.4, 07 section 2.4), built from a `FoundryRowView`.
## No nodes: `FoundryRow` copies these fields into labels. All strings come from existing keys; numbers go through
## `NumberFormat` / `UpgradeRowModel.format_value` (one value style per row id, same as the run panel).
## (impl) The delta is the start-value change of the next level, shown as "+x" after the value line (no string key).

var index: int = -1
var id: String = ""
var kind: String = ""
var name_text: String = ""
var level: int = 0
var level_text: String = ""
## `x1.00 -> x1.06` (Type D multiplier) or `0 -> 2` (Type C start value); the single value at the cap.
var value_text: String = ""
## `+1.2`: start-value gain of the next level ("" at the cap).
var delta_text: String = ""
## MILESTONE F25  x1.75 (Type D) or MAX; "" for a Type C row that is not capped.
var milestone_text: String = ""
## AFFORDABLE / ~12m 30s TO AFFORD / x3 COST UNTIL WAVE N (over the soft cap); "" when unknown or maxed.
var afford_text: String = ""
var cost_text: String = ""
var tooltip_text: String = ""
var affordable: bool = false
var maxed: bool = false
## Over the soft cap (R1-02): the cost is multiplied, the button stays enabled in the over-limit color, the afford line
## reads "x3 COST UNTIL WAVE N". `room_below_limit` is how many more levels cost the normal price (a hold stops at 0).
var over_limit: bool = false
var room_below_limit: int = 0
var recommended: bool = false
## Levels to the next milestone (-1 for Type C and a maxed row); the row uses it to spot a crossed milestone.
var levels_to_milestone: int = -1


static func from_view(view: FoundryRowView, row_index: int) -> FoundryRowModel:
	var m: FoundryRowModel = FoundryRowModel.new()
	m.index = row_index
	m.id = view.id
	m.kind = view.kind
	m.name_text = UpgradeRowModel.upgrade_name(view.id)
	m.level = view.level
	m.level_text = Strings.fill1("foundry.level", "n", str(view.level))
	m.maxed = view.maxed
	m.affordable = view.affordable and not view.maxed
	m.recommended = view.recommended and not view.maxed
	m.over_limit = view.over_limit
	m.room_below_limit = view.room_below_limit
	m.levels_to_milestone = view.levels_to_milestone
	m.value_text = _value(view)
	if view.maxed:
		m.milestone_text = Strings.get_text("foundry.max")
		m.cost_text = Strings.get_text("foundry.max")
	else:
		m.cost_text = NumberFormat.format(view.cost)
		if view.delta != 0.0:
			m.delta_text = "+" + UpgradeRowModel.format_value(view.id, view.delta)
		if view.kind == "D":
			m.milestone_text = (
				Strings
				. fill(
					"foundry.milestone",
					{
						"n": str(view.level + view.levels_to_milestone),
						"m": UpgradeRowModel.mult_arg(view.milestone_mult),
					}
				)
			)
		m.afford_text = _over_text(view) if view.over_limit else _afford(view)
	m.tooltip_text = _tooltip(view)
	return m


## The row's first line: value now -> next, then the delta.
func value_line() -> String:
	return value_text if delta_text == "" else value_text + "  " + delta_text


static func _value(view: FoundryRowView) -> String:
	var now: String
	var nxt: String
	if view.kind == "D":
		now = mult_text(view.mult_now)
		nxt = mult_text(view.mult_next)
	else:
		now = UpgradeRowModel.format_value(view.id, view.start_now)
		nxt = UpgradeRowModel.format_value(view.id, view.start_next)
	if view.maxed:
		return now
	return Strings.fill("foundry.value", {"a": now, "b": nxt})


## "x3 COST UNTIL WAVE 24": the over-the-soft-cap line.
static func _over_text(view: FoundryRowView) -> String:
	return Strings.fill("foundry.over_cost", {"m": UpgradeRowModel.mult_arg(view.over_mult), "n": str(view.next_wave)})


static func _afford(view: FoundryRowView) -> String:
	if view.affordable:
		return Strings.get_text("foundry.afford_now")
	if view.afford_in_minutes < 0.0:
		return ""
	var secs: int = ceili(view.afford_in_minutes * 60.0)
	return Strings.fill1("foundry.afford_in", "v", NumberFormat.format_time(secs))


## Formula tooltip: level, next cost, cap (the run panel's tooltip pattern), plus the start values.
static func _tooltip(view: FoundryRowView) -> String:
	var key: String = "foundry.tooltip_d" if view.kind == "D" else "foundry.tooltip_c"
	var cost: String = "-" if view.maxed else NumberFormat.format(view.cost)
	var text: String = (
		Strings
		. fill(
			key,
			{
				"f": str(view.level),
				"cost": cost,
				"cap": str(view.cap),
				"m": UpgradeRowModel.mult_arg(view.milestone_mult),
				"s": str(view.milestone_step),
			}
		)
	)
	if not view.maxed:
		var over_m: String = UpgradeRowModel.mult_arg(view.over_mult)
		text += "\n" + Strings.fill("foundry.tooltip_rule", {"cap": str(view.limit), "m": over_m})
		if view.over_limit:
			text += "\n" + Strings.fill("foundry.tooltip_over", {"m": over_m, "n": str(view.next_wave)})
	var start: String = UpgradeRowModel.format_value(view.id, view.start_now)
	return text + "\n" + Strings.fill1("foundry.value_start", "v", start)


## `x1.06`: two decimals while small (the spec shows x1.00 -> x1.06), compact after.
static func mult_text(v: float) -> String:
	if v < 100.0:
		return "x%.2f" % v
	return NumberFormat.format_mult(v)
