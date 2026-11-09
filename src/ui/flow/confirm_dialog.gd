class_name ConfirmDialog
extends Control
## A modal two-button plate dialog (M3-30): dim backdrop, heading, body, YES and NO. Built in code (no scene), hidden
## until `open`. `confirmed` / `cancelled` fire after the dialog closed itself; `AudioHooks.tap` plays on a press.
## Used by the router (NEW GAME) and the Settings Data section (RESET PROFILE, twice). Back closes it (`cancel`).

signal confirmed
signal cancelled

const WIDTH: float = 880.0
const TITLE_PX: int = 72
const BODY_PX: int = 44

var _title: Label
var _body: Label
var _yes: Button
var _no: Button


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var plate := PanelContainer.new()
	plate.theme_type_variation = ThemeBuilder.VAR_PANEL_PLATE
	plate.custom_minimum_size = Vector2(WIDTH, 0.0)
	center.add_child(plate)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 32)
	plate.add_child(box)
	_title = MenuScreen.label("", &"LabelHeading", Palette.AMBER, TITLE_PX)
	box.add_child(_title)
	_body = MenuScreen.label("", &"LabelDim", Palette.TEXT, BODY_PX)
	box.add_child(_body)
	_yes = MenuScreen.make_button("title.quit_yes", _on_yes)
	box.add_child(_yes)
	_no = MenuScreen.make_button("title.quit_no", _on_no)
	box.add_child(_no)


## Shows the dialog with already localized texts.
func open(heading_text: String, message: String) -> void:
	_title.text = heading_text
	_body.text = message
	show()


func close() -> void:
	hide()


func is_open() -> bool:
	return visible


## The back gesture: closes and reports `cancelled`. False when the dialog was not open.
func cancel() -> bool:
	if not visible:
		return false
	_on_no()
	return true


func title_text() -> String:
	return _title.text


func body_text() -> String:
	return _body.text


func yes_button() -> Button:
	return _yes


func no_button() -> Button:
	return _no


func _on_yes() -> void:
	AudioHooks.tap()
	hide()
	confirmed.emit()


func _on_no() -> void:
	AudioHooks.tap()
	hide()
	cancelled.emit()
