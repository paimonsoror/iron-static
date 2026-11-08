class_name UpgradePanel
extends PanelContainer
## The bottom-44% upgrade panel (M2-10; GDD 07 sections 2.1, 2.2): tabs ARMS / CHASSIS / SYSTEMS / INTEL,
## buy modes x1 x10 x100 MAX, one pre-instanced `UpgradeRow` per upgrade def (shown per tab and visibility),
## a `Next unlock at wave N` line at the end of the list. Reads the bound `SimWorld` every 0.1 s from a Timer
## (no `_process`) and never mutates it: a row's buy button only emits `buy_requested(index, count)`;
## M2-12 connects that to `world.command_buy`.

signal buy_requested(upgrade_index: int, count: int)

const REFRESH_S: float = 0.1
const PANEL_MARGIN: float = 12.0
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
	var frame: StyleBoxFlat = theme.get_stylebox("panel", "PanelContainer").duplicate() as StyleBoxFlat
	frame.set_content_margin_all(PANEL_MARGIN)
	add_theme_stylebox_override("panel", frame)
	_setup_tabs()
	_setup_buy_modes()
	_intel_label.text = Strings.get_text("panel.intel_stub")
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
	_tab_buttons[tab_id].set_pressed_no_signal(true)
	_scroll.scroll_vertical = 0
	refresh()
	return true


## Selects x1 / x10 / x100 / Max (-1) (no signal); false for any other count.
func set_buy_mode(count: int) -> bool:
	if not model.set_buy_mode(count):
		return false
	_buy_buttons[UpgradePanelModel.BUY_MODES.find(count)].set_pressed_no_signal(true)
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
	for tab_id: String in UpgradePanelModel.TAB_IDS:
		var b: Button = _tab_bar.get_node("Tab_" + tab_id)
		b.toggle_mode = true
		b.button_group = group
		b.text = Strings.get_text("tab." + tab_id)
		b.pressed.connect(_on_tab_pressed.bind(tab_id))
		_tab_buttons[tab_id] = b
	_tab_buttons[model.active_tab].set_pressed_no_signal(true)


func _setup_buy_modes() -> void:
	var group := ButtonGroup.new()
	(_buy_bar.get_node("BuyLabel") as Label).text = Strings.get_text("buy.label")
	for k: int in UpgradePanelModel.BUY_MODES.size():
		var b: Button = _buy_bar.get_node("Buy_%d" % k)
		b.toggle_mode = true
		b.button_group = group
		b.text = Strings.get_text(UpgradePanelModel.BUY_KEYS[k])
		b.pressed.connect(_on_buy_mode_pressed.bind(UpgradePanelModel.BUY_MODES[k]))
		_buy_buttons.append(b)
	_buy_buttons[UpgradePanelModel.BUY_MODES.find(model.buy_mode)].set_pressed_no_signal(true)


func _on_tab_pressed(tab_id: String) -> void:
	set_tab(tab_id)


func _on_buy_mode_pressed(count: int) -> void:
	set_buy_mode(count)
