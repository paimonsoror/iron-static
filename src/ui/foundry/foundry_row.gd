class_name FoundryRow
extends UpgradeRow
## One Foundry row (M3-16): the run panel's `UpgradeRow` (tap = 1 level on release, hold = `RepeatBuyModel` repeats,
## a drag past 24 px or a scrolling list cancels, row body tap = tooltip, `RowFx` ring and pulse) with three info
## lines, a RECOMMENDED tag and a data icon on the cost button. The hold logic is inherited, not forked.
## Soft cap (R1-02): a row over the limit is never disabled. Its cost button keeps the dark plate and shows the cost in
## `Palette.OVER_LIMIT`; a fresh tap buys one level at the multiplied price, a hold stops at the first over-limit level
## (the over-limit state is the LOCKED state of the base row, whose hold ends on a repeat) and its steps never cross the
## limit (`_room`).
## `buy_pressed(index, count)` is the only purchase signal; `released` fires after a release (and after a cancelled
## hold) so the screen can write the save once the buy of that release has landed.

signal released

const LINE_SIZE: int = 36
const TAG_SIZE: int = 30
const ROW_H: float = 252.0
const OVER_COLOR_KEYS: PackedStringArray = [
	"font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"
]

var _releasing: bool = false
var _data_icon: Texture2D = null
var _tag: Label = null
var _over_buyable: bool = false  ## over the soft cap and affordable: a tap buys, a hold does not
var _room: int = 0  ## levels left at the normal price

@onready var _milestone_label: Label = %MilestoneLabel
@onready var _afford_label: Label = %AffordLabel


func _ready() -> void:
	super()
	custom_minimum_size.y = ROW_H
	_data_icon = ArtSlots.texture("icon_cur_data")
	_milestone_label.add_theme_font_size_override("font_size", LINE_SIZE)
	_milestone_label.add_theme_color_override("font_color", Palette.AMBER_TEXT)
	_afford_label.add_theme_font_size_override("font_size", LINE_SIZE)
	_afford_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_tag = Label.new()
	_tag.text = Strings.get_text("foundry.recommended")
	_tag.theme_type_variation = ThemeBuilder.VAR_LABEL_DIM
	_tag.add_theme_font_size_override("font_size", TAG_SIZE)
	_tag.add_theme_color_override("font_color", Palette.AMBER_GLOW)
	_tag.add_theme_stylebox_override("normal", UiKit.tab_active(14, 6))
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tag.custom_minimum_size.y = 46.0
	_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tag.hide()
	_tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_buy_button.get_parent().add_child(_tag)  # under the cost button: the info lines keep the full width (M4-27)


## Copies the model into the nodes (the base row for icon, name, level, cost state and ring).
func apply_foundry(model: FoundryRowModel) -> void:
	_over_buyable = model.over_limit and model.affordable
	_room = model.room_below_limit
	var m: UpgradeRowModel = UpgradeRowModel.new()
	m.index = model.index
	m.upgrade_id = model.id
	m.name_text = model.name_text
	m.level = model.level
	m.level_text = model.level_text
	m.value_text = model.value_line()
	m.cost_text = model.cost_text
	m.tooltip_text = model.tooltip_text
	m.maxed = model.maxed
	m.affordable = model.affordable and not model.over_limit  # the over-limit look is the dark plate, see _style_over
	m.milestone_glow = model.recommended
	m.levels_to_milestone = model.levels_to_milestone
	apply(m)
	_milestone_label.text = model.milestone_text
	_milestone_label.visible = model.milestone_text != ""
	_afford_label.text = model.afford_text
	_afford_label.visible = model.afford_text != ""
	var afford_color: Color = Palette.AMBER_GLOW if model.affordable else Palette.TEXT_DIM
	_afford_label.add_theme_color_override("font_color", Palette.OVER_LIMIT if model.over_limit else afford_color)
	_tag.visible = model.recommended
	_buy_button.disabled = model.maxed  # never locked by the soft cap (R1-02)
	_style_over(model)


## The cost button of an over-limit row: enabled, the cost in the over-limit color, a data icon when it can be bought.
func _style_over(model: FoundryRowModel) -> void:
	var over_color: Color = Palette.OVER_LIMIT
	for key: String in OVER_COLOR_KEYS:
		if model.over_limit and not model.maxed:
			_buy_button.add_theme_color_override(key, over_color)
		else:
			_buy_button.remove_theme_color_override(key)
	if model.maxed:
		return
	if _state == CostState.AFFORDABLE or _over_buyable:
		_buy_button.icon = _data_icon
	else:
		_buy_button.icon = UiKit.lock_icon()


## A fresh tap over the limit buys one level at the multiplied price (the base row would play the deny sound for its
## LOCKED state); a hold repeat never crosses the limit: steps are clamped to the room left at the normal price.
func _request(count: int) -> void:
	if _repeated:
		if _state != CostState.AFFORDABLE or _room <= 0:
			_stop_hold()  # a repeat never buys over the limit or without the Data
			AudioHooks.deny()
			return
		super(mini(count, _room))
		return
	if _over_buyable:
		_fx.play_flash()
		AudioHooks.buy_step()
		buy_pressed.emit(_index, 1)
		return
	super(count)


func is_recommended() -> bool:
	return _tag != null and _tag.visible


func has_glow() -> bool:
	return _ring


func cost_text() -> String:
	return _cost


func value_text() -> String:
	return _value


func milestone_text() -> String:
	return _milestone_label.text


func afford_text() -> String:
	return _afford_label.text


func buy_button() -> Button:
	return _buy_button


func _on_button_up() -> void:
	_releasing = true
	super()
	_releasing = false
	released.emit()


func _stop_hold() -> void:
	var was: bool = _holding
	super()
	if was and not _releasing:
		released.emit()
