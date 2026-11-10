class_name DraftCard
extends Control
## One offer of the patch draft (M4-16, I-04 in R1-04): a plate with the stat icon (160 px, on a family-colored
## backing: amber ARMS, teal CHASSIS, scrap-gold SYSTEMS), the patch name, the family tag, the concrete change for this
## run ("LASER OUTPUT 28.6 > 32.9") and, in a lower band, the pick pips (picks held of max). A gamble has a dashed
## amber border and its lower band is tinted red and carries the cost line. 340 px tall (touch target >= 148). Acts on a
## COMPLETED tap only, like `PauseButtons`: press and release on this card, not cancelled, finger within
## `PauseButtons.TAP_SLOP_PX`; a press that began before the card was shown never counts (the gesture-navigation back
## swipe cancels its touch). Emits `chosen(slot)`.

signal chosen(slot: int)

const CARD_H: float = 340.0
const BAND_H: float = 96.0
const ICON_PX: float = 160.0
const NAME_SIZE: int = 56
const BODY_SIZE: int = 40
const TAG_SIZE: int = 34
const BORDER_INSET: float = 12.0
const DASH_PX: float = 22.0
const BORDER_W: float = 5.0
const PIP_R: float = 11.0
const PIP_STEP: float = 34.0
const BACKING_ALPHA: float = 0.22
const GAMBLE_TINT: Color = Color(1.0, 0.231, 0.188, 0.24)  # Palette.CRITICAL at 24%

var data: DraftCardData = null

var _press_pos: Vector2 = PauseButtons.NO_PRESS
var _down: bool = false
var _plate: StyleBoxTexture = null
var _plate_pressed: StyleBoxTexture = null
var _icon: TextureRect = null
var _backing: Control = null
var _title: Label = null
var _tag: Label = null
var _change: Label = null
var _band_text: Label = null
var _pips: Control = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0.0, CARD_H)


func _ready() -> void:
	_plate = UiKit.button()
	_plate_pressed = UiKit.button_pressed()
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 0)
	margin.add_child(rows)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 28)
	rows.add_child(top)
	_backing = Control.new()
	_backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backing.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	_backing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_backing.draw.connect(_draw_backing)
	top.add_child(_backing)
	_icon = UiKit.icon_rect("icon_ic_lock", ICON_PX)
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backing.add_child(_icon)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	top.add_child(column)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	_title = _label(ThemeBuilder.VAR_LABEL_HEADING, NAME_SIZE, Palette.AMBER_GLOW)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_tag = _label(ThemeBuilder.VAR_LABEL_NUMBER, TAG_SIZE, Palette.AMBER)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tag.autowrap_mode = TextServer.AUTOWRAP_OFF  # an autowrap label in a row would shrink to one letter per line
	head.add_child(_tag)
	_change = _label(ThemeBuilder.VAR_LABEL_NUMBER, BODY_SIZE, Palette.TEXT)
	column.add_child(_change)
	var band := HBoxContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.custom_minimum_size = Vector2(0.0, BAND_H - 14.0)
	band.add_theme_constant_override("separation", 20)
	rows.add_child(band)
	_pips = Control.new()
	_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pips.custom_minimum_size = Vector2(PIP_STEP, PIP_R * 2.0)
	_pips.draw.connect(_draw_pips)
	_band_text = _label(ThemeBuilder.VAR_LABEL_NUMBER, TAG_SIZE + 2, Palette.TEXT_DIM)
	_band_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_band_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	band.add_child(_pips)
	band.add_child(_band_text)
	_refresh()


func set_data(card: DraftCardData) -> void:
	data = card
	_press_pos = PauseButtons.NO_PRESS
	_down = false
	_refresh()
	queue_redraw()


## Test hook: the rendered texts (name, change lines joined by a newline, cost line or "").
func texts() -> PackedStringArray:
	var cost: String = _band_text.text if data != null and data.gamble else ""
	return PackedStringArray([_title.text, _change.text, cost])


func _refresh() -> void:
	if _title == null or data == null:
		return
	var accent: Color = DraftCardData.family_color(data.family)
	_title.text = data.title
	_change.text = "\n".join(data.change_lines)
	_tag.text = data.family_text()
	_tag.add_theme_color_override("font_color", accent)
	_icon.texture = ArtSlots.texture(data.icon_slot)
	if data.gamble:
		_tag.text = "%s  %s" % [Strings.get_text("draft.gamble"), data.family_text()]
		_band_text.text = data.cost_line
		_band_text.add_theme_color_override("font_color", Palette.CRITICAL)
		_band_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		_band_text.text = "%d/%d" % [data.qty, data.max_picks]
		_band_text.add_theme_color_override("font_color", Palette.TEXT_DIM)
		_band_text.size_flags_horizontal = Control.SIZE_FILL
	_pips.custom_minimum_size = Vector2(PIP_STEP * float(data.max_picks), PIP_R * 2.0)
	_pips.queue_redraw()
	_backing.queue_redraw()


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
	if data == null:
		return
	var accent: Color = DraftCardData.family_color(data.family)
	draw_rect(Rect2(0.0, BORDER_INSET * 2.0, 8.0, size.y - BORDER_INSET * 4.0), accent)  # family stripe on the left
	if data.gamble:
		var band := Rect2(BORDER_INSET, size.y - BAND_H, size.x - BORDER_INSET * 2.0, BAND_H - BORDER_INSET)
		draw_rect(band, GAMBLE_TINT)
		_draw_dashed_border()


func _draw_backing() -> void:
	if data == null:
		return
	var accent: Color = DraftCardData.family_color(data.family)
	var r := Rect2(Vector2.ZERO, _backing.size)
	_backing.draw_rect(r, Color(accent, BACKING_ALPHA))
	_backing.draw_rect(r, accent, false, 3.0)


## Pips: one per max pick, filled for picks held, the next one (this pick) as a bright ring.
func _draw_pips() -> void:
	if data == null:
		return
	var accent: Color = DraftCardData.family_color(data.family)
	for i: int in data.max_picks:
		var c := Vector2(PIP_R + PIP_STEP * float(i), _pips.size.y * 0.5)
		if i < data.qty:
			_pips.draw_circle(c, PIP_R, accent)
		elif i == data.qty:
			_pips.draw_arc(c, PIP_R - 1.5, 0.0, TAU, 24, Palette.AMBER_GLOW, 3.0)
		else:
			_pips.draw_arc(c, PIP_R - 1.5, 0.0, TAU, 24, Palette.TEXT_DIM, 2.0)


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
