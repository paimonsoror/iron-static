class_name UpgradeRow
extends PanelContainer
## One row of the upgrade panel (M2-09, restyled V1-17; GDD 07 section 2.2, art bible 7.3): upgrade icon, name, `L24`
## in the number font, `current > next`, cost button (affordable = amber plate with pulse, unaffordable = dim plate
## with a lock mark, maxed = MAX plate with the hazard stripe), gold ring near a x25 milestone, long-press (0.4 s)
## tooltip on the tooltip plate. Presentation only: `apply(model)` copies an `UpgradeRowModel` into the nodes and
## rewrites a node only when its value changed. Effects are drawn by `RowFx`. Signals only: the panel turns
## `buy_pressed` into `buy_requested(index, count)`.
## (impl) The 4 px press depress is the pressed plate of the cost button; the 120 ms flash is `RowFx`.

signal buy_pressed(upgrade_index: int)

enum CostState { AFFORDABLE, LOCKED, MAXED }

const LONG_PRESS_S: float = 0.4
const TOOLTIP_S: float = 3.0
const MOVE_CANCEL_PX: float = 24.0
const SCROLL_CANCEL_PX: float = 8.0
## Row height: 148 px cost button plus 18 px above and below (was 231 px; Q56 asks for more rows on screen).
const ROW_MIN_H: float = 184.0
const NAME_SIZE: int = 42
const LEVEL_SIZE: int = 38
const COST_SIZE: int = 44
const COST_ICON_PX: int = 52

var _index: int = -1
var _name: String = ""
var _level: String = ""
var _level_n: int = -1
var _value: String = ""
var _cost: String = ""
var _tooltip: String = ""
var _icon_id: String = ""
var _state: int = -1
var _ring: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_y: float = 0.0
var _hazard: Panel = null
var _scrap_icon: Texture2D = null

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel
@onready var _value_label: Label = %ValueLabel
@onready var _buy_button: Button = %BuyButton
@onready var _fx: RowFx = %Fx
@onready var _tip: PanelContainer = %Tooltip
@onready var _tip_label: Label = %TooltipLabel
@onready var _press_timer: Timer = %PressTimer
@onready var _tip_timer: Timer = %TipTimer


func _ready() -> void:
	custom_minimum_size.y = ROW_MIN_H
	add_theme_stylebox_override("panel", UiKit.inset(16, 8))
	_style_labels()
	_style_cost_button()
	_tip.add_theme_stylebox_override("panel", UiKit.tooltip(20, 6))
	_fx.button = _buy_button
	_press_timer.wait_time = LONG_PRESS_S
	_tip_timer.wait_time = TOOLTIP_S
	_press_timer.timeout.connect(_on_long_press)
	_tip_timer.timeout.connect(_hide_tip)
	_buy_button.pressed.connect(_on_buy_pressed)
	_tip.hide()


## Copies the model into the nodes; unchanged fields are not touched.
func apply(model: UpgradeRowModel) -> void:
	_index = model.index
	if model.upgrade_id != _icon_id:
		_icon_id = model.upgrade_id
		_icon.texture = ArtSlots.texture(UpgradeIcons.slot_for(_icon_id))
		_icon.modulate = UpgradeIcons.tint_for(_icon_id)
	if model.name_text != _name:
		_name = model.name_text
		_name_label.text = _name
	if model.level_text != _level:
		_level = model.level_text
		_level_label.text = _level
	if model.level != _level_n:
		# Crossing a multiple of 25 by a purchase (not the first bind) plays the 0.4 s expansion.
		if _level_n >= 0 and floori(float(model.level) / 25.0) > floori(float(_level_n) / 25.0):
			_fx.play_expand()
		_level_n = model.level
	if model.value_text != _value:
		_value = model.value_text
		_value_label.text = _value
	if model.cost_text != _cost:
		_cost = model.cost_text
		_buy_button.text = _cost
	if model.tooltip_text != _tooltip:
		_tooltip = model.tooltip_text
		_tip_label.text = _tooltip
	var state: int = (
		CostState.MAXED if model.maxed else (CostState.AFFORDABLE if model.affordable else CostState.LOCKED)
	)
	if state != _state:
		_state = state
		_apply_state()
	if model.milestone_glow != _ring:
		_ring = model.milestone_glow
		_fx.ring = _ring
	var reduced: bool = Game.visual.reduce_motion
	if reduced != _fx.reduced:
		_fx.reduced = reduced


func upgrade_index() -> int:
	return _index


func is_tooltip_visible() -> bool:
	return _tip.visible


func cost_state() -> int:
	return _state


func _style_labels() -> void:
	_name_label.add_theme_font_size_override("font_size", NAME_SIZE)
	_level_label.add_theme_font_size_override("font_size", LEVEL_SIZE)
	_level_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_level_label.add_theme_stylebox_override("normal", UiKit.tab(12, 0))
	_level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _style_cost_button() -> void:
	var font: Font = ThemeBuilder.shared().get_font("font", ThemeBuilder.VAR_LABEL_NUMBER)
	_buy_button.add_theme_font_override("font", font)
	_buy_button.add_theme_font_size_override("font_size", COST_SIZE)
	_buy_button.add_theme_constant_override("icon_max_width", COST_ICON_PX)
	_buy_button.add_theme_constant_override("h_separation", 14)
	_buy_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_buy_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_scrap_icon = ArtSlots.texture("icon_cur_scrap")
	_hazard = UiKit.add_hazard(_buy_button, 28.0, 14.0)
	_hazard.hide()


func _apply_state() -> void:
	var maxed: bool = _state == CostState.MAXED
	_buy_button.disabled = maxed
	_hazard.visible = maxed
	match _state:
		CostState.AFFORDABLE:
			_buy_button.theme_type_variation = ThemeBuilder.VAR_BUTTON_AFFORDABLE
			_buy_button.icon = _scrap_icon
			_buy_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		CostState.LOCKED:
			_buy_button.theme_type_variation = ThemeBuilder.VAR_BUTTON_UNAFFORDABLE
			_buy_button.icon = UiKit.lock_icon()
			_buy_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_:
			_buy_button.theme_type_variation = ThemeBuilder.VAR_BUTTON_MAXED
			_buy_button.icon = null
			_buy_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fx.pulse = _state == CostState.AFFORDABLE


func _gui_input(event: InputEvent) -> void:
	# (impl) Presses are read from both the emulated mouse events and the raw touch events (a device may deliver
	# only one of them to a row inside a ScrollContainer); starting the timer twice is harmless.
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_press_changed(mb.pressed, mb.position)
		return
	var st: InputEventScreenTouch = event as InputEventScreenTouch
	if st != null:
		_press_changed(st.pressed, st.position)
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_press_moved(mm.position)
		return
	var sd: InputEventScreenDrag = event as InputEventScreenDrag
	if sd != null:
		_press_moved(sd.position)


func _press_changed(pressed: bool, pos: Vector2) -> void:
	if not pressed:
		_press_timer.stop()
		return
	if not _press_timer.is_stopped():
		return  # second source (mouse and touch) of the same press
	_hide_tip()
	_press_pos = pos
	_press_y = global_position.y
	_press_timer.start()


func _press_moved(pos: Vector2) -> void:
	if not _press_timer.is_stopped() and pos.distance_to(_press_pos) > MOVE_CANCEL_PX:
		_press_timer.stop()


func _on_long_press() -> void:
	# A scroll drag moves the row under the finger: no tooltip then.
	if absf(global_position.y - _press_y) > SCROLL_CANCEL_PX:
		return
	_tip.show()
	_tip_timer.start()


func _hide_tip() -> void:
	_tip_timer.stop()
	_tip.hide()


func _on_buy_pressed() -> void:
	if _state == CostState.AFFORDABLE:
		_fx.play_flash()
	buy_pressed.emit(_index)
