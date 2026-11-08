class_name UpgradeRow
extends PanelContainer
## One row of the upgrade panel (M2-09; GDD 07 section 2.2): icon, name, `L24`, `current > next`, cost button,
## gold ring near a x1.5 milestone, long-press (0.4 s) tooltip. Presentation only: `apply(model)` copies an
## `UpgradeRowModel` into the nodes and rewrites a node only when its text or state changed.
## Signals only: the panel turns `buy_pressed` into `buy_requested(index, count)`.
## (impl) The icon is a colored square (no icon art yet) and the gold ring is steady, not flashing.

signal buy_pressed(upgrade_index: int)

const LONG_PRESS_S: float = 0.4
const TOOLTIP_S: float = 3.0
const MOVE_CANCEL_PX: float = 24.0
const SCROLL_CANCEL_PX: float = 8.0
const RING_WIDTH: int = 6

var _index: int = -1
var _name: String = ""
var _level: String = ""
var _value: String = ""
var _cost: String = ""
var _tooltip: String = ""
var _affordable: bool = true
var _maxed: bool = false
var _glow: bool = false
var _icon_color: Color = Color(0, 0, 0, 0)
var _press_pos: Vector2 = Vector2.ZERO
var _press_y: float = 0.0
var _style_plain: StyleBoxFlat = null
var _style_glow: StyleBoxFlat = null

@onready var _icon: ColorRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel
@onready var _value_label: Label = %ValueLabel
@onready var _buy_button: Button = %BuyButton
@onready var _tip: PanelContainer = %Tooltip
@onready var _tip_label: Label = %TooltipLabel
@onready var _press_timer: Timer = %PressTimer
@onready var _tip_timer: Timer = %TipTimer


func _ready() -> void:
	_style_plain = _make_style(Palette.GRID, 2)
	_style_glow = _make_style(Palette.AMBER_GLOW, RING_WIDTH)
	add_theme_stylebox_override("panel", _style_plain)
	_press_timer.wait_time = LONG_PRESS_S
	_tip_timer.wait_time = TOOLTIP_S
	_press_timer.timeout.connect(_on_long_press)
	_tip_timer.timeout.connect(_hide_tip)
	_buy_button.pressed.connect(_on_buy_pressed)
	_tip.hide()


## Copies the model into the nodes; unchanged fields are not touched.
func apply(model: UpgradeRowModel) -> void:
	_index = model.index
	if model.name_text != _name:
		_name = model.name_text
		_name_label.text = _name
	if model.level_text != _level:
		_level = model.level_text
		_level_label.text = _level
	if model.value_text != _value:
		_value = model.value_text
		_value_label.text = _value
	if model.cost_text != _cost:
		_cost = model.cost_text
		_buy_button.text = _cost
	if model.tooltip_text != _tooltip:
		_tooltip = model.tooltip_text
		_tip_label.text = _tooltip
	if model.icon_color != _icon_color:
		_icon_color = model.icon_color
		_icon.color = _icon_color
	if model.maxed != _maxed:
		_maxed = model.maxed
		_buy_button.disabled = _maxed
	var dim: bool = not model.affordable
	if dim == _affordable:
		_affordable = not dim
		_buy_button.theme_type_variation = (&"" if _affordable else ThemeBuilder.VAR_BUTTON_UNAFFORDABLE)
	if model.milestone_glow != _glow:
		_glow = model.milestone_glow
		add_theme_stylebox_override("panel", _style_glow if _glow else _style_plain)


func upgrade_index() -> int:
	return _index


func is_tooltip_visible() -> bool:
	return _tip.visible


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_hide_tip()
			_press_pos = mb.position
			_press_y = global_position.y
			_press_timer.start()
		else:
			_press_timer.stop()
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and not _press_timer.is_stopped():
		if mm.position.distance_to(_press_pos) > MOVE_CANCEL_PX:
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
	buy_pressed.emit(_index)


static func _make_style(border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PANEL.lerp(Color.WHITE, 0.04)
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(ThemeBuilder.CORNER)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb
