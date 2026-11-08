class_name PauseOverlay
extends Control
## Full-screen "paused" cover (V1-24): dim, a plate with the title and the two hints. Any press resumes. Hidden by
## default; while shown it blocks touches to the HUD underneath. Texts come from data/strings_en.csv.

signal resume_requested


func _ready() -> void:
	theme = ThemeBuilder.shared()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Palette.VOID, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(900.0, 0.0)
	card.theme_type_variation = &"PanelPlate"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	column.add_child(_label("pause.title", &"LabelHeading", Palette.AMBER, 96))
	column.add_child(_label("pause.resume_hint", &"LabelNumber", Palette.AMBER_GLOW, 56))
	column.add_child(_label("pause.exit_hint", &"LabelNumber", Palette.TEXT_DIM, 44))


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var mouse := event as InputEventMouseButton
	if (touch != null and touch.pressed) or (mouse != null and mouse.pressed):
		accept_event()
		resume_requested.emit()


static func _label(key: String, variation: StringName, color: Color, size_px: int) -> Label:
	var l := Label.new()
	l.text = Strings.get_text(key)
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size_px)
	return l
