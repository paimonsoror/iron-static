class_name PauseOverlay
extends Control
## The in-battle pause menu (V1-24, reworked for the pause menu): dim, a centered plate card with PAUSED, an optional
## notice line ("RUN RESTORED") and three buttons, RESUME, ABORT MISSION, EXIT GAME (`PauseButtons`). Tapping outside
## the buttons does nothing. ABORT MISSION asks a `ConfirmDialog` (ABORT / CANCEL) first. Hidden by default; while
## shown it blocks touches to the HUD underneath. Signals: `resume_requested`, `abort_requested` (after the confirm),
## `exit_requested`. Texts come from data/strings_en.csv. Back handling lives in `BackPolicy` / `MobileShell`.

signal resume_requested
signal abort_requested
signal exit_requested

## Card width in base px (side margins of 100 px on the 1080 reference).
const CARD_W: float = 880.0

var _notice: Label = null
var _buttons: PauseButtons = null
var _confirm: ConfirmDialog = null


## One notice line under the title (M3-14: "RUN RESTORED" after a resume, the save notices). "" hides it.
func set_notice(text: String) -> void:
	if _notice == null:
		return
	_notice.text = text
	_notice.visible = text != ""


func notice_text() -> String:
	return _notice.text if _notice != null and _notice.visible else ""


func buttons() -> PauseButtons:
	return _buttons


func confirm() -> ConfirmDialog:
	return _confirm


func confirm_open() -> bool:
	return _confirm != null and _confirm.is_open()


## The back gesture on the ABORT MISSION confirm: closes it only (the menu stays). False when it was not open.
func cancel_confirm() -> bool:
	return _confirm != null and _confirm.cancel()


func _ready() -> void:
	theme = ThemeBuilder.shared()
	# In the tree already: set_anchors_preset alone would keep the current 0x0 rect (offsets become -viewport size)
	# and the card centered on the top-left corner on the phone. Zero the offsets too.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Palette.VOID, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_W, 0.0)
	card.theme_type_variation = &"PanelPlate"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 32)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	column.add_child(_label("pause.title", &"LabelHeading", Palette.AMBER, 96))
	_notice = _label("pause.title", &"LabelNumber", Palette.TEXT, 44)
	_notice.visible = false
	column.add_child(_notice)
	_buttons = PauseButtons.new()
	_buttons.pressed.connect(_on_row_pressed)
	column.add_child(_buttons)
	_confirm = ConfirmDialog.new()  # added last: above the card
	_confirm.confirmed.connect(_on_abort_confirmed)
	add_child(_confirm)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible and _confirm != null:
		_confirm.close()  # the menu closing (resume, abort, back) takes an open confirm with it


## Swallows every touch the card and the buttons do not take: tapping outside the buttons does nothing.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		accept_event()


func _on_abort_confirmed() -> void:
	abort_requested.emit()


func _on_row_pressed(row_id: String) -> void:
	match row_id:
		PauseButtons.ROW_RESUME:
			resume_requested.emit()
		PauseButtons.ROW_ABORT:
			AudioHooks.tap()
			_confirm.open(
				Strings.get_text("pause.abort_title"),
				Strings.get_text("pause.abort_body"),
				Strings.get_text("pause.abort_yes"),
				Strings.get_text("pause.abort_no")
			)
		PauseButtons.ROW_EXIT:
			exit_requested.emit()


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
