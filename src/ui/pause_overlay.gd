class_name PauseOverlay
extends Control
## Full-screen "paused" cover (V1-24): dim, a plate with the title and the two hints. A tap resumes. Hidden by
## default; while shown it blocks touches to the HUD underneath. Texts come from data/strings_en.csv.

signal resume_requested

## Largest finger travel (base px, ~23 dp) between press and release that still counts as a tap.
const TAP_SLOP_PX: float = 60.0
const NO_PRESS: Vector2 = Vector2(INF, INF)

var _notice: Label = null
## Where the current press started on the overlay (NO_PRESS = none seen since it was shown).
var _press_pos: Vector2 = NO_PRESS


## One notice line under the title (M3-14: "RUN RESTORED" after a resume, the save notices). "" hides it.
func set_notice(text: String) -> void:
	if _notice == null:
		return
	_notice.text = text
	_notice.visible = text != ""


func notice_text() -> String:
	return _notice.text if _notice != null and _notice.visible else ""


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
	_notice = _label("pause.title", &"LabelNumber", Palette.TEXT, 44)
	_notice.visible = false
	column.add_child(_notice)
	column.add_child(_label("pause.resume_hint", &"LabelNumber", Palette.AMBER_GLOW, 56))
	column.add_child(_label("pause.exit_hint", &"LabelNumber", Palette.TEXT_DIM, 44))


## True when a press at `from` released at `to` is a tap: a press was seen, the release was not cancelled and the
## finger stayed within TAP_SLOP_PX. Phone bug: with gesture navigation the back swipe from the screen edge first
## delivers a touch press to the app, then Android takes the gesture over and cancels the touch. Resuming on that
## press made "BACK AGAIN TO EXIT" impossible, so the overlay resumes on a completed tap only.
static func is_tap(from: Vector2, to: Vector2, canceled: bool) -> bool:
	return from != NO_PRESS and not canceled and from.distance_to(to) <= TAP_SLOP_PX


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_press_pos = NO_PRESS  # a press that started before the overlay appeared never resumes


## Touch and the mouse emulated from it both arrive on a phone: the first release resumes and clears the press,
## so the twin release is ignored.
func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if touch == null and mouse == null:
		return
	accept_event()
	var pressed: bool = touch.pressed if touch != null else mouse.pressed
	var pos: Vector2 = touch.position if touch != null else mouse.position
	var canceled: bool = touch.canceled if touch != null else mouse.canceled
	if pressed:
		_press_pos = pos
		return
	var tap: bool = is_tap(_press_pos, pos, canceled)
	_press_pos = NO_PRESS
	if tap:
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
