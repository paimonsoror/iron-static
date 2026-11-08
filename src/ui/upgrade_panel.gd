class_name UpgradePanel
extends PanelContainer
## The bottom upgrade panel (M2-10; GDD 07 sections 2.1, 2.2): tabs ARMS / CHASSIS / SYSTEMS / INTEL,
## one pre-instanced `UpgradeRow` per upgrade def (shown per tab and visibility), a `Next unlock at wave N` line at
## the end of the list. V1-25: no buy-mode selector (a row's cost button buys 1 on tap, repeats on hold), and the
## panel height follows its content (tabs + rows + hint) capped at `max_height_px`, scrolling inside; it is anchored
## to the bottom and grows upward (`reflow`). Reads the bound `SimWorld` every 0.1 s from a Timer (no `_process`)
## and never mutates it: a row only emits `buy_requested(index, count)`; M2-12 connects that to `world.command_buy`.

signal buy_requested(upgrade_index: int, count: int)

const REFRESH_S: float = 0.1
const PANEL_MARGIN_H: float = 20.0
const PANEL_MARGIN_V: float = 16.0
const TAB_ICON_PX: int = 56
## Wide layout: tab label size (the side column is narrower than four portrait tabs) and cost button min width.
const WIDE_TAB_FONT: int = 34
const WIDE_COST_MIN_W: float = 204.0
const ROW_COST_MIN_W: float = 316.0
const ROW_SCENE: PackedScene = preload("res://src/ui/upgrade_row.tscn")

var model: UpgradePanelModel = UpgradePanelModel.new()
## Height cap in px (the HUD sets 36 percent of its height); 0 = 36 percent of the viewport.
var max_height_px: float = 0.0
## Wide layout (V1-28): the panel is a full-height side column; the list fills it and scrolls inside.
var wide: bool = false:
	set(value):
		wide = value
		_apply_wide()

var _world: SimWorld = null
var _defs: Array[RunUpgradeDef] = []
var _rows: Array[UpgradeRow] = []
var _hint: String = ""
var _tab_buttons: Dictionary[String, Button] = {}

@onready var _tab_bar: HBoxContainer = %TabBar
@onready var _column: VBoxContainer = %Column
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
	_intel_label.text = Strings.get_text("panel.intel_stub")
	_intel_label.add_theme_stylebox_override("normal", UiKit.inset(24, 40))
	_hint_label.hide()
	_intel_label.hide()
	_timer.wait_time = REFRESH_S
	_timer.timeout.connect(refresh)
	_timer.start()
	_rows_box.minimum_size_changed.connect(reflow)
	reflow()


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


## Selects a tab (no signal); false for an unknown id.
func set_tab(tab_id: String) -> bool:
	if not model.set_tab(tab_id):
		return false
	_show_selected_tab()
	_scroll.scroll_vertical = 0
	refresh()
	return true


## Sizes the panel to its content: tab bar plus rows, capped at `max_height_px`, anchored at the bottom edge.
func reflow() -> void:
	if not is_node_ready():
		return
	if wide:
		_scroll.custom_minimum_size.y = 0.0
		return
	var cap: float = max_height_px
	if cap <= 0.0:
		cap = get_viewport_rect().size.y * 0.36
	var chrome: float = get_theme_stylebox("panel").get_minimum_size().y
	chrome += _tab_bar.get_combined_minimum_size().y + float(_column.get_theme_constant("separation"))
	var scroll_h: float = clampf(_rows_box.get_combined_minimum_size().y, 0.0, maxf(cap - chrome, 0.0))
	if not is_equal_approx(_scroll.custom_minimum_size.y, scroll_h):
		_scroll.custom_minimum_size.y = scroll_h
	var want_top: float = offset_bottom - (chrome + scroll_h)
	if not is_equal_approx(offset_top, want_top):
		offset_top = want_top


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
		var p: UpgradePreview = UpgradeSystem.preview(_world, i, 1)
		_rows[i].apply(UpgradeRowModel.from_preview(p, p.affordable, p.level, _defs[i]))
	var hint: String = "" if intel else UpgradePanelModel.hint_text(_defs, _world.config.best_wave_s1)
	if hint != _hint:
		_hint = hint
		_hint_label.text = hint
		_hint_label.visible = not hint.is_empty()
	reflow()


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
		_compact_row(row)
		row.buy_pressed.connect(_on_row_buy)
		_rows.append(row)


func _on_row_buy(upgrade_index: int, count: int) -> void:
	buy_requested.emit(upgrade_index, count)


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
	AudioHooks.tap()
	@warning_ignore("return_value_discarded")
	set_tab(tab_id)


## `set_pressed_no_signal` does not release the other buttons of a ButtonGroup: set every button explicitly
## (otherwise a code-driven switch leaves two tabs or chips highlighted).
func _show_selected_tab() -> void:
	for tab_id: String in _tab_buttons:
		_tab_buttons[tab_id].set_pressed_no_signal(tab_id == model.active_tab)


## Tab font and cost button width for the wide side column (portrait values restored otherwise).
func _apply_wide() -> void:
	if not is_node_ready():
		return
	for b: Button in _tab_buttons.values():
		if wide:
			b.add_theme_font_size_override("font_size", WIDE_TAB_FONT)
		else:
			b.remove_theme_font_size_override("font_size")
	for row: UpgradeRow in _rows:
		_compact_row(row)


func _compact_row(row: UpgradeRow) -> void:
	var buy: Control = row.get_node("%BuyButton")
	buy.custom_minimum_size.x = WIDE_COST_MIN_W if wide else ROW_COST_MIN_W
