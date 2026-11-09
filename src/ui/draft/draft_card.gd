class_name DraftCard
extends Control
## One offer of the patch draft (M4-16): a plate with the patch name, its benefit and, on a gamble, a GAMBLE tag, the
## cost line and a dashed amber border. 300 px tall (touch target >= 148). Acts on a COMPLETED tap only, like
## `PauseButtons`: press and release on this card, not cancelled, finger within `PauseButtons.TAP_SLOP_PX`; a press
## that began before the card was shown never counts (the gesture-navigation back swipe cancels its touch). Emits
## `chosen(slot)`.

signal chosen(slot: int)

const CARD_H: float = 300.0
const NAME_SIZE: int = 56
const BODY_SIZE: int = 40
const TAG_SIZE: int = 38
const BORDER_INSET: float = 12.0
const DASH_PX: float = 22.0
const BORDER_W: float = 5.0

var data: DraftCardData = null

var _press_pos: Vector2 = PauseButtons.NO_PRESS
var _down: bool = false
var _plate: StyleBoxTexture = null
var _plate_pressed: StyleBoxTexture = null
var _title: Label = null
var _tag: Label = null
var _benefit: Label = null
var _cost: Label = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0.0, CARD_H)


func _ready() -> void:
	_plate = UiKit.button()
	_plate_pressed = UiKit.button_pressed()
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	_title = _label(ThemeBuilder.VAR_LABEL_HEADING, NAME_SIZE, Palette.AMBER_GLOW)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_tag = _label(ThemeBuilder.VAR_LABEL_NUMBER, TAG_SIZE, Palette.WARNING)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tag.autowrap_mode = TextServer.AUTOWRAP_OFF  # an autowrap label in a row would shrink to one letter per line
	head.add_child(_tag)
	_benefit = _label(ThemeBuilder.VAR_LABEL_NUMBER, BODY_SIZE, Palette.TEXT)
	column.add_child(_benefit)
	_cost = _label(ThemeBuilder.VAR_LABEL_NUMBER, BODY_SIZE, Palette.WARNING)
	column.add_child(_cost)
	_refresh()


func set_data(card: DraftCardData) -> void:
	data = card
	_press_pos = PauseButtons.NO_PRESS
	_down = false
	_refresh()
	queue_redraw()


## Test hook: the rendered texts (name, benefit, cost line or "").
func texts() -> PackedStringArray:
	return PackedStringArray([_title.text, _benefit.text, _cost.text if _cost.visible else ""])


func _refresh() -> void:
	if _title == null or data == null:
		return
	_title.text = data.title
	_benefit.text = data.benefit
	_cost.text = data.cost_line
	_cost.visible = data.gamble
	if data.gamble:
		_tag.text = Strings.get_text("draft.gamble")
	elif data.qty > 0:
		_tag.text = "%d/%d" % [data.qty, data.max_picks]
	else:
		_tag.text = ""
	_tag.visible = _tag.text != ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_press_pos = PauseButtons.NO_PRESS  # a press from before the overlay opened never activates
		_down = false
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if touch == null and mouse == null:
		return
	accept_event()
	var is_down: bool = touch.pressed if touch != null else mouse.pressed
	var pos: Vector2 = touch.position if touch != null else mouse.position
	var canceled: bool = touch.canceled if touch != null else mouse.canceled
	if is_down:
		_down = true
		_press_pos = pos
		queue_redraw()
		return
	var inside: bool = Rect2(Vector2.ZERO, size).has_point(pos)
	var hit: bool = _down and inside and PauseButtons.is_tap(_press_pos, pos, canceled)
	_down = false
	_press_pos = PauseButtons.NO_PRESS
	queue_redraw()
	if hit and data != null:
		chosen.emit(data.slot)


func _draw() -> void:
	if _plate == null:
		return
	draw_style_box(_plate_pressed if _down else _plate, Rect2(Vector2.ZERO, size))
	if data != null and data.gamble:
		_draw_dashed_border()


func _draw_dashed_border() -> void:
	var r := Rect2(Vector2.ONE * BORDER_INSET, size - Vector2.ONE * BORDER_INSET * 2.0)
	var tl: Vector2 = r.position
	var tr := Vector2(r.end.x, r.position.y)
	var br: Vector2 = r.end
	var bl := Vector2(r.position.x, r.end.y)
	draw_dashed_line(tl, tr, Palette.AMBER, BORDER_W, DASH_PX)
	draw_dashed_line(tr, br, Palette.AMBER, BORDER_W, DASH_PX)
	draw_dashed_line(br, bl, Palette.AMBER, BORDER_W, DASH_PX)
	draw_dashed_line(bl, tl, Palette.AMBER, BORDER_W, DASH_PX)


static func _label(variation: StringName, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size_px)
	return l
