class_name ServiceRecordScreen
extends MenuScreen
## SERVICE RECORD (lifetime statistics of the profile): time played, deployments, machines destroyed by type, combat,
## economy and per-frame lines, in one scrolling list. Opened from Home (RECORD), BACK returns to the opener. Read
## only: every control in the list ignores the mouse (`MOUSE_FILTER_IGNORE`), so a touch drag that starts on a stat row
## reaches the ScrollContainer. The structure is built once; `enter()` refreshes the texts from the profile each time
## the screen is shown. Signals are final: back_pressed.

signal back_pressed

const HEADING_PX: int = 80
const SECTION_PX: int = 54
const LABEL_PX: int = 38
const VALUE_PX: int = 44
const NOTE_PX: int = 32
const ROW_PAD: int = 14
const LIST_GAP: int = 28

var scroll: ScrollContainer
var back_button: Button
var since_label: Label
var seeded_label: Label
var gaps_label: Label
## Name labels and value labels of every row, in display order (tests read them).
var name_labels: Array[Label] = []
var value_labels: Array[Label] = []
var model: RecordModel = null

var _profile: PlayerProfile = null
var _enemy_ids: PackedStringArray = PackedStringArray()
var _modes: Array[WaveModeDef] = []
var _frames: Array[FrameDef] = []
var _list: VBoxContainer = null
var _built_rows: int = -1


func title_key() -> String:
	return "record.title"


## Optional: show a given profile instead of `Game.profile()` (tests, captures).
func setup(profile: PlayerProfile) -> void:
	_profile = profile
	if scroll != null:
		enter()


func _build() -> void:
	for def: EnemyDef in SimConfigLoader.load_default(1).enemies:
		@warning_ignore("return_value_discarded")
		_enemy_ids.append(def.id)
	_modes = ModeRules.load_defs()
	_frames = FrameRules.load_defs()
	heading.add_theme_font_size_override("font_size", HEADING_PX)
	since_label = label("", &"LabelDim", Palette.TEXT_DIM, LABEL_PX)
	content.add_child(since_label)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.scroll_deadzone = 24
	content.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", LIST_GAP)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_list)
	back_button = make_button("record.back", _on_back)
	content.add_child(back_button)
	enter()


## Refreshes every text from the profile (the router calls this each time the screen is shown).
func enter() -> void:
	if scroll == null:
		return
	var p: PlayerProfile = _profile if _profile != null else Game.profile()
	model = RecordModel.build(p, _enemy_ids, _modes, _frames)
	var rows: int = 0
	for s: RecordSection in model.sections:
		rows += s.size()
	if rows != _built_rows:
		_rebuild(rows)
	since_label.text = model.since_text
	since_label.visible = not model.since_text.is_empty()
	seeded_label.text = model.seeded_note
	seeded_label.visible = not model.seeded_note.is_empty()
	gaps_label.text = model.gaps_note
	gaps_label.visible = not model.gaps_note.is_empty()
	var k: int = 0
	for s: RecordSection in model.sections:
		for i: int in s.size():
			name_labels[k].text = s.labels[i]
			value_labels[k].text = s.values[i]
			k += 1
	scroll.scroll_vertical = 0


## The row structure (sections, plates, labels). Runs on the first show, and again only if the row count changed.
func _rebuild(rows: int) -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	name_labels.clear()
	value_labels.clear()
	seeded_label = _note()
	gaps_label = _note()
	_list.add_child(seeded_label)
	_list.add_child(gaps_label)
	for s: RecordSection in model.sections:
		_list.add_child(_section(s))
	var foot: Label = _note()
	foot.text = Strings.get_text("record.footnote")
	_list.add_child(foot)
	_built_rows = rows


func _section(s: RecordSection) -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	var head: Label = label("", &"LabelHeading", Palette.AMBER, SECTION_PX)
	head.text = s.title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(head)
	var plate := PanelContainer.new()
	plate.theme_type_variation = ThemeBuilder.VAR_PANEL_PLATE
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", ROW_PAD)
	for i: int in s.size():
		rows.add_child(_row())
	plate.add_child(rows)
	box.add_child(plate)
	return box


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 24)
	var name_label: Label = label("", &"LabelDim", Palette.TEXT_DIM, LABEL_PX)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	var value: Label = label("", &"LabelNumber", Palette.AMBER_GLOW, VALUE_PX)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(value)
	name_labels.append(name_label)
	value_labels.append(value)
	return row


func _note() -> Label:
	var l: Label = label("", &"LabelDim", Palette.TEXT_DIM, NOTE_PX)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


func _on_back() -> void:
	AudioHooks.tap()
	back_pressed.emit()
