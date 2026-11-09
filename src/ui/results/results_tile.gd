class_name ResultsTile
extends PanelContainer
## One results stat tile (M4): icon on the left, the number big, a one-word caption and an optional small second line.

const ICON_PX: float = 72.0
const NUMBER_SIZE: int = 56

var _value: Label = null
var _caption: Label = null
var _extra: Label = null


## `icon_slot` is an art slot id ("icon_ic_clock"); `color` tints the number.
func setup(icon_slot: String, caption: String, color: Color, with_extra: bool = false) -> void:
	add_theme_stylebox_override("panel", UiKit.inset(18, 10))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	add_child(row)
	var icon: TextureRect = UiKit.icon_rect(icon_slot, ICON_PX)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", -2)
	row.add_child(col)
	_value = Label.new()
	_value.theme_type_variation = ThemeBuilder.VAR_LABEL_NUMBER
	_value.add_theme_font_size_override("font_size", NUMBER_SIZE)
	_value.add_theme_color_override("font_color", color)
	_value.clip_text = true
	col.add_child(_value)
	_caption = _dim_label(caption)
	col.add_child(_caption)
	if with_extra:
		_extra = _dim_label("")
		col.add_child(_extra)


func set_value(text: String) -> void:
	_value.text = text


func set_extra(text: String) -> void:
	if _extra != null:
		_extra.text = text
		_extra.visible = not text.is_empty()


func value_label() -> Label:
	return _value


func caption_label() -> Label:
	return _caption


func extra_label() -> Label:
	return _extra


func _dim_label(text: String) -> Label:
	var l := Label.new()
	l.theme_type_variation = ThemeBuilder.VAR_LABEL_DIM
	l.text = text
	l.clip_text = true
	return l
