class_name FoundryRow
extends UpgradeRow
## One Foundry row (M3-16): the run panel's `UpgradeRow` (tap = 1 level on release, hold = `RepeatBuyModel` repeats,
## a drag past 24 px or a scrolling list cancels, row body tap = tooltip, `RowFx` ring and pulse) with three info
## lines, a RECOMMENDED tag and a data icon on the cost button. The hold logic is inherited, not forked.
## `buy_pressed(index, count)` is the only purchase signal; `released` fires after a release (and after a cancelled
## hold) so the screen can write the save once the buy of that release has landed.

signal released

const LINE_SIZE: int = 36
const TAG_SIZE: int = 30
const ROW_H: float = 252.0

var _releasing: bool = false
var _data_icon: Texture2D = null
var _tag: Label = null

@onready var _milestone_label: Label = %MilestoneLabel
@onready var _afford_label: Label = %AffordLabel


func _ready() -> void:
	super()
	custom_minimum_size.y = ROW_H
	_data_icon = ArtSlots.texture("icon_cur_data")
	_milestone_label.add_theme_font_size_override("font_size", LINE_SIZE)
	_milestone_label.add_theme_color_override("font_color", Palette.AMBER_DIM)
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
	m.affordable = model.affordable
	m.milestone_glow = model.recommended
	apply(m)
	_milestone_label.text = model.milestone_text
	_milestone_label.visible = model.milestone_text != ""
	_afford_label.text = model.afford_text
	_afford_label.visible = model.afford_text != ""
	_afford_label.add_theme_color_override("font_color", Palette.AMBER_GLOW if model.affordable else Palette.TEXT_DIM)
	_tag.visible = model.recommended
	if _state == CostState.AFFORDABLE:
		_buy_button.icon = _data_icon


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
