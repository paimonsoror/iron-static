class_name UpgradePanel
extends PanelContainer
## The bottom-44% upgrade panel (M2-10; GDD 07 sections 2.1, 2.2): tabs ARMS / CHASSIS / SYSTEMS / INTEL,
## buy modes x1 x10 x100 MAX, one pre-instanced `UpgradeRow` per upgrade def (shown per tab and visibility),
## a `Next unlock at wave N` line at the end of the list. Reads the bound `SimWorld` every 0.1 s from a Timer
## (no `_process`) and never mutates it: a row's buy button only emits `buy_requested(index, count)`;
## M2-12 connects that to `world.command_buy`.

signal buy_requested(upgrade_index: int, count: int)

const REFRESH_S: float = 0.1
const PANEL_MARGIN_H: float = 20.0
const PANEL_MARGIN_V: float = 16.0
const TAB_ICON_PX: int = 56
const CHIP_FONT_SIZE: int = 48
const ROW_SCENE: PackedScene = preload("res://src/ui/upgrade_row.tscn")

var model: UpgradePanelModel = UpgradePanelModel.new()

var _world: SimWorld = null
var _defs: Array[RunUpgradeDef] = []
var _rows: Array[UpgradeRow] = []
var _hint: String = ""
var _tab_buttons: Dictionary[String, Button] = {}
var _buy_buttons: Array[Button] = []

@onready var _tab_bar: HBoxContainer = %TabBar
@onready var _buy_bar: HBoxContainer = %BuyBar
@onready var _scroll: ScrollContainer = %Scroll
@onready var _rows_box: VBoxContainer = %RowsBox
@onready var _hint_label: Label = %HintLabel
@onready var _intel_label: Label = %IntelLabel
@onready var _timer: Timer = %RefreshTimer


func _ready() -> void:
	theme = ThemeBuilder.shared()
	add_theme_stylebox_override("panel", UiKit.plate(PANEL_MARGIN_H, PANEL_MARGIN_V))
	var brackets := Control.new()
	brackets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(brackets)
	UiKit.add_brackets(brackets)
	_setup_tabs()
	_setup_buy_modes()
	_intel_label.text = Strings.get_text("panel.intel_stub")
	_intel_label.add_theme_stylebox_override("normal", UiKit.inset(24, 40))
	_hint_label.hide()
	_intel_label.hide()
	_timer.wait_time = REFRESH_S
	_timer.timeout.connect(refresh)
	_timer.start()


## Binds the world to read (a new run gives a new world). Rows are rebuilt only when the upgrade table differs.
func bind(world: SimWorld) -> void:
	_world = world
	if world == null:
		return
	if not _same_defs(world.config.upgrades):
		_build_rows(world.config.upgrades)
	refresh()


func bound_world() -> SimWorld:
	return _world


func active_tab() -> String:
	return model.active_tab


func buy_mode() -> int:
	return model.buy_mode


## Selects a tab (no signal); false for an unknown id.
func set_tab(tab_id: String) -> bool:
	if not model.set_tab(tab_id):
		return false
	_show_selected_tab()
	_scroll.scroll_vertical = 0
	refresh()
	return true


## Selects x1 / x10 / x100 / Max (-1) (no signal); false for any other count.
func set_buy_mode(count: int) -> bool:
	if not model.set_buy_mode(count):
		return false
	_show_selected_mode()
	refresh()
	return true


## Row widget of upgrade `index` (tests, layout checks), or null.
func row_at(index: int) -> UpgradeRow:
	if index < 0 or index >= _rows.size():
		return null
	return _rows[index]


## Re-reads the world and updates the active tab. Called by the timer; safe to call directly.
func refresh() -> void:
	if _world == null or _rows.size() != _world.config.upgrades.size():
		return
	var intel: bool = model.active_tab == UpgradePanelModel.TAB_INTEL
	_intel_label.visible = intel
	var shown: PackedInt32Array = PackedInt32Array()
	if not intel:
		shown = UpgradePanelModel.rows_for_tab(_defs, _world.visible, model.active_tab)
	for i: int in _rows.size():
		var want: bool = shown.has(i)
		if _rows[i].visible != want:
			_rows[i].visible = want
	for i: int in shown:
		var p: UpgradePreview = UpgradeSystem.preview(_world, i, model.buy_mode)
		_rows[i].apply(UpgradeRowModel.from_preview(p, p.affordable, p.level, _defs[i]))
	var hint: String = "" if intel else UpgradePanelModel.hint_text(_defs, _world.config.best_wave_s1)
	if hint != _hint:
		_hint = hint
		_hint_label.text = hint
		_hint_label.visible = not hint.is_empty()


func _same_defs(defs: Array[RunUpgradeDef]) -> bool:
	if defs.size() != _defs.size():
		return false
	for i: int in defs.size():
		if defs[i] != _defs[i]:
			return false
	return true


func _build_rows(defs: Array[RunUpgradeDef]) -> void:
	for row: UpgradeRow in _rows:
		row.queue_free()
	_rows.clear()
	_defs = defs.duplicate()
	for i: int in defs.size():
		var row: UpgradeRow = ROW_SCENE.instantiate()
		row.visible = false
		_rows_box.add_child(row)
		_rows_box.move_child(row, i)
		row.buy_pressed.connect(_on_row_buy)
		_rows.append(row)


func _on_row_buy(upgrade_index: int) -> void:
	buy_requested.emit(upgrade_index, model.buy_mode)


func _setup_tabs() -> void:
	var group := ButtonGroup.new()
	var normal: StyleBoxTexture = UiKit.tab(12, 10)
	var active: StyleBoxTexture = UiKit.tab_active(12, 10)
	for tab_id: String in UpgradePanelModel.TAB_IDS:
		var b: Button = _tab_bar.get_node("Tab_" + tab_id)
		b.toggle_mode = true
		b.button_group = group
		b.text = Strings.get_text("tab." + tab_id)
		b.pressed.connect(_on_tab_pressed.bind(tab_id))
		_touch_style(b, normal, normal, active, active)
		for color_name: String in ["font_color", "font_hover_color", "font_focus_color"]:
			b.add_theme_color_override(color_name, Palette.AMBER)
		for color_name: String in ["font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(color_name, Palette.TEXT)
		b.add_theme_font_override("font", theme.get_font("font", ThemeBuilder.VAR_LABEL_HEADING))
		b.add_theme_constant_override("icon_max_width", TAB_ICON_PX)
		b.add_theme_constant_override("h_separation", 0)
		UiKit.set_icon(b, "icon_tab_" + tab_id)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		_tab_buttons[tab_id] = b
	_show_selected_tab()


func _setup_buy_modes() -> void:
	var group := ButtonGroup.new()
	(_buy_bar.get_node("BuyLabel") as Label).text = Strings.get_text("buy.label")
	var normal: StyleBoxTexture = UiKit.button(12, 10)
	var active: StyleBoxTexture = UiKit.button_active(12, 10)
	var font: Font = theme.get_font("font", ThemeBuilder.VAR_LABEL_NUMBER)
	for k: int in UpgradePanelModel.BUY_MODES.size():
		var b: Button = _buy_bar.get_node("Buy_%d" % k)
		b.toggle_mode = true
		b.button_group = group
		b.text = Strings.get_text(UpgradePanelModel.BUY_KEYS[k])
		b.pressed.connect(_on_buy_mode_pressed.bind(UpgradePanelModel.BUY_MODES[k]))
		# Selected chip = `button_plate_active`; hover and focus look like normal so a swipe leaves no stuck highlight (Q55).
		_touch_style(b, normal, normal, active, active)
		b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", CHIP_FONT_SIZE)
		if UpgradePanelModel.BUY_MODES[k] == -1:
			var strip: Panel = UiKit.add_hazard(b, 28.0, 16.0)
			strip.name = "Hazard"
		_buy_buttons.append(b)
	_show_selected_mode()


## Touch-safe styling of a toggle button: no focus box (a tap would leave it stuck), hover = normal.
## `on` / `hover_on` are the selected plates.
func _touch_style(b: Button, normal: StyleBox, hover: StyleBox, on: StyleBox, hover_on: StyleBox) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", hover_on)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _on_tab_pressed(tab_id: String) -> void:
	set_tab(tab_id)


func _on_buy_mode_pressed(count: int) -> void:
	set_buy_mode(count)


## `set_pressed_no_signal` does not release the other buttons of a ButtonGroup: set every button explicitly
## (otherwise a code-driven switch leaves two tabs or chips highlighted).
func _show_selected_tab() -> void:
	for tab_id: String in _tab_buttons:
		_tab_buttons[tab_id].set_pressed_no_signal(tab_id == model.active_tab)


func _show_selected_mode() -> void:
	var selected: int = UpgradePanelModel.BUY_MODES.find(model.buy_mode)
	for k: int in _buy_buttons.size():
		_buy_buttons[k].set_pressed_no_signal(k == selected)
