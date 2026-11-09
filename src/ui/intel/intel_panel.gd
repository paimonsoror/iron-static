class_name IntelPanel
extends VBoxContainer
## The INTEL tab's Stats panel (M4-18; GDD 02 section 15): a heading and one card per `IntelRow` (stat name and final
## value on the first line, the base / run / Foundry / frame / patch chain below it). Hosted by `UpgradePanel` inside
## its scroll list. Reads the bound `SimWorld` at most every 0.25 s while visible (own Timer, no `_process`), never
## mutates it, and writes a label only when its text changed. Card widgets are created once and reused.
## Touch: cards are read-only; the list scrolls by drag like the upgrade rows.

const REFRESH_S: float = 0.25
const NAME_SIZE: int = 42
const CHAIN_SIZE: int = 38
const CARD_PAD_H: float = 24.0
const CARD_PAD_V: float = 14.0

var _world: SimWorld = null
var _cards: Array[PanelContainer] = []
var _names: Array[Label] = []
var _values: Array[Label] = []
var _chains: Array[Label] = []
var _title: Label = null
var _timer: Timer = null


func _ready() -> void:
	theme = ThemeBuilder.shared()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	_title = Label.new()
	_title.theme_type_variation = ThemeBuilder.VAR_LABEL_HEADING
	_title.text = Strings.get_text("intel.stats.title")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Palette.AMBER)
	add_child(_title)
	_timer = Timer.new()
	_timer.wait_time = REFRESH_S
	_timer.timeout.connect(refresh)
	add_child(_timer)
	_timer.start()
	visibility_changed.connect(refresh)


## Binds the world to read (a new run gives a new world) and shows its rows.
func bind(world: SimWorld) -> void:
	_world = world
	refresh()


## Rebuilds the row texts from the world. Skipped while hidden or unbound.
func refresh() -> void:
	if _world == null or not is_visible_in_tree():
		return
	var rows: Array[IntelRow] = IntelModel.build(_world)
	while _cards.size() < rows.size():
		_add_card()
	for i: int in _cards.size():
		var on: bool = i < rows.size()
		if _cards[i].visible != on:
			_cards[i].visible = on
		if not on:
			continue
		_set_text(_names[i], rows[i].name_text)
		_set_text(_values[i], rows[i].value_text)
		_set_text(_chains[i], rows[i].chain_text)


func card_count() -> int:
	return _cards.size()


## Text of card `i`: [name, value, chain] (tests).
func card_texts(i: int) -> PackedStringArray:
	return PackedStringArray([_names[i].text, _values[i].text, _chains[i].text])


func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


func _add_card() -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.inset(CARD_PAD_H, CARD_PAD_V))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	card.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", NAME_SIZE)
	name_label.add_theme_color_override("font_color", Palette.AMBER)
	head.add_child(name_label)
	var value_label := Label.new()
	value_label.theme_type_variation = ThemeBuilder.VAR_LABEL_NUMBER
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(value_label)
	var chain_label := Label.new()
	chain_label.theme_type_variation = ThemeBuilder.VAR_LABEL_DIM
	chain_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chain_label.add_theme_font_size_override("font_size", CHAIN_SIZE)
	chain_label.custom_minimum_size.x = 100.0
	box.add_child(chain_label)
	add_child(card)
	_cards.append(card)
	_names.append(name_label)
	_values.append(value_label)
	_chains.append(chain_label)
