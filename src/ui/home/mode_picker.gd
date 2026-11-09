class_name ModePicker
extends VBoxContainer
## Wave mode picker above DEPLOY on Home (M4-08): one segment per `ModeCard`, side by side, at least 148 px tall.
## The only UI that knows several modes, and it knows none by name: it renders whatever cards `ModeRules.cards`
## returns (a third mode is data only). The selected segment wears the active plate; a locked segment is dimmed,
## stays tappable and shows its lock condition and progress in the info panel instead of selecting. A one-time
## chip line ("PURGE MODE UNLOCKED") can take the info panel until the next tap.
## `setup(cards, selected)` is idempotent; `mode_selected(id)` fires for an unlocked, not yet selected segment.

signal mode_selected(id: String)

const SEGMENT_PX: int = 52
const INFO_PX: int = 40
const SEPARATION: int = 16
const LOCKED_ALPHA: float = 0.5

var selected_id: String = ""
var _cards: Array[ModeCard] = []
var _buttons: Dictionary[String, Button] = {}
var _row: HBoxContainer
var _info_plate: PanelContainer
var _info_label: Label


func _init() -> void:
	add_theme_constant_override("separation", SEPARATION)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", SEPARATION)
	add_child(_row)
	_info_plate = PanelContainer.new()
	_info_plate.theme_type_variation = ThemeBuilder.VAR_PANEL_INSET
	_info_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_plate.visible = false
	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_label.add_theme_font_size_override("font_size", INFO_PX)
	_info_plate.add_child(_info_label)
	add_child(_info_plate)


## Rebuilds the segments. `selected` must be an unlocked card; otherwise the first unlocked one is shown selected.
func setup(cards: Array[ModeCard], selected: String) -> void:
	_cards = cards
	selected_id = selected
	if not _is_unlocked(selected_id):
		selected_id = _first_unlocked()
	for b: Button in _buttons.values():
		_row.remove_child(b)
		b.queue_free()
	_buttons.clear()
	for c: ModeCard in cards:
		var b := Button.new()
		b.text = Strings.get_text(c.name_key)
		b.custom_minimum_size = Vector2(0.0, float(ThemeBuilder.TOUCH_MIN_HEIGHT))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", SEGMENT_PX)
		b.pressed.connect(press.bind(c.id))
		_row.add_child(b)
		_buttons[c.id] = b
	_restyle()


## The tap on a segment (public so tests can drive it). Locked: shows the condition, emits nothing.
func press(id: String) -> void:
	var card: ModeCard = _find(id)
	if card == null:
		return
	if not card.unlocked:
		show_info(card.locked_text + "\n" + card.progress_text)
		return
	_info_plate.visible = false
	if id == selected_id:
		return
	selected_id = id
	_restyle()
	mode_selected.emit(id)


## Puts a line in the info panel (the unlock chip, or a lock condition).
func show_info(text: String) -> void:
	_info_label.text = text
	_info_plate.visible = true


func info_visible() -> bool:
	return _info_plate.visible


func info_text() -> String:
	return _info_label.text


func button_of(id: String) -> Button:
	return _buttons.get(id, null)


func _restyle() -> void:
	for c: ModeCard in _cards:
		var b: Button = _buttons[c.id]
		var on: bool = c.id == selected_id
		b.theme_type_variation = ThemeBuilder.VAR_BUTTON_CHIP_ACTIVE if on else ThemeBuilder.VAR_BUTTON_PLATE
		b.add_theme_color_override("font_color", Palette.AMBER_GLOW if on else Palette.AMBER)
		b.self_modulate = Color(1.0, 1.0, 1.0, 1.0 if c.unlocked else LOCKED_ALPHA)
		if c.unlocked:
			b.icon = null
		else:
			b.icon = UiKit.lock_icon()
			b.expand_icon = false


func _find(id: String) -> ModeCard:
	for c: ModeCard in _cards:
		if c.id == id:
			return c
	return null


func _is_unlocked(id: String) -> bool:
	var c: ModeCard = _find(id)
	return c != null and c.unlocked


func _first_unlocked() -> String:
	for c: ModeCard in _cards:
		if c.unlocked:
			return c.id
	return ""
