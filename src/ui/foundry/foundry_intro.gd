class_name FoundryIntro
extends Control
## The Foundry explainer dialog (FO-1): dim backdrop, a plate with the title, four short paragraphs, a "don't show
## this again" toggle and GOT IT. Built in code (no scene), hidden until `open`; no animation, so nothing to reduce.
## `dismissed(hide_next_time)` fires after the dialog closed itself (GOT IT or `dismiss`, the back gesture); the
## owner stores the flag. The look is the `ConfirmDialog` plate.

signal dismissed(hide_next_time: bool)

const WIDTH: float = 1080.0 - 2.0 * UiKit.MENU_SIDE_MARGIN
const TITLE_PX: int = 72
const BODY_PX: int = 44
const BODY_KEYS: PackedStringArray = ["foundry.intro.p1", "foundry.intro.p2", "foundry.intro.p3", "foundry.intro.p4"]

var _title: Label
var _toggle: SettingsToggle
var _ok: Button
var _paragraphs: Array[Label] = []


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
	box.add_theme_constant_override("separation", 28)
	plate.add_child(box)
	_title = MenuScreen.label("foundry.intro.title", &"LabelHeading", Palette.AMBER, TITLE_PX)
	box.add_child(_title)
	for key: String in BODY_KEYS:
		var p: Label = MenuScreen.label(key, &"LabelDim", Palette.TEXT, BODY_PX)
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		box.add_child(p)
		_paragraphs.append(p)
	_toggle = SettingsToggle.new()
	_toggle.text = Strings.get_text("foundry.intro.hide")
	box.add_child(_toggle)
	_ok = MenuScreen.make_button("foundry.intro.ok", _on_ok)
	box.add_child(_ok)


## Shows the dialog; the toggle starts as `hidden_now` (the stored flag).
func open(hidden_now: bool) -> void:
	_toggle.set_value_silent(hidden_now)
	show()


func close() -> void:
	hide()


func is_open() -> bool:
	return visible


## The back gesture: same as GOT IT. False when the dialog was not open.
func dismiss() -> bool:
	if not visible:
		return false
	_on_ok()
	return true


func ticked() -> bool:
	return _toggle.button_pressed


func toggle_button() -> SettingsToggle:
	return _toggle


func ok_button() -> Button:
	return _ok


func title_text() -> String:
	return _title.text


## The visible text of the paragraphs, joined by a space.
func body_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for p: Label in _paragraphs:
		parts.append(p.text)
	return " ".join(parts)


func _on_ok() -> void:
	AudioHooks.tap()
	hide()
	dismissed.emit(_toggle.button_pressed)
