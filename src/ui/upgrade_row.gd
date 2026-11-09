class_name UpgradeRow
extends PanelContainer
## One row of the upgrade panel (M2-09, restyled V1-17; GDD 07 section 2.2, art bible 7.3): upgrade icon, name, `L24`
## in the number font, `current > next`, cost button (affordable = amber plate with pulse, unaffordable = dim plate
## with a lock mark, maxed = MAX plate with the hazard stripe), gold ring near a x25 milestone, long-press (0.4 s)
## tooltip on the tooltip plate. Presentation only: `apply(model)` copies an `UpgradeRowModel` into the nodes and
## rewrites a node only when its value changed. Effects are drawn by `RowFx`. Signals only: the panel forwards
## `buy_pressed(index, count)` as `buy_requested(index, count)`.
## V1-25 buying: tap the cost button = buy 1 on release; press and hold = repeat buys timed by `RepeatBuyModel`
## (first repeat 0.35 s, then faster and in steps of 10 / 100). A drag past `MOVE_CANCEL_PX` or a scrolled row
## cancels the press (the list scrolls instead). Tapping the row body (not the cost button) toggles the tooltip.
## (impl) The 4 px press depress is the pressed plate of the cost button; the 120 ms flash is `RowFx`.

signal buy_pressed(upgrade_index: int, count: int)

enum CostState { AFFORDABLE, LOCKED, MAXED }

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
var _icon_id: String = ""
var _state: int = -1
var _ring: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_y: float = 0.0
var _tap_armed: bool = false
var _repeat: RepeatBuyModel = RepeatBuyModel.new()
var _holding: bool = false
var _hold_s: float = 0.0
var _repeated: bool = false
var _ptr: Vector2 = Vector2.ZERO
var _down_pos: Vector2 = Vector2.ZERO
var _down_y: float = 0.0
var _hazard: Panel = null
var _scrap_icon: Texture2D = null
var _tip: RowTooltip = RowTooltip.new()
var _tier_mark: RowTierMark = RowTierMark.new()

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _level_label: Label = %LevelLabel
@onready var _value_label: Label = %ValueLabel
@onready var _buy_button: Button = %BuyButton
@onready var _fx: RowFx = %Fx
## VT-6 nodes exist in upgrade_row.tscn only (the Foundry row scene reuses this script without them).
@onready var _tier_line: HBoxContainer = get_node_or_null("%TierLine")
@onready var _mark_label: Label = get_node_or_null("%MarkLabel")
@onready var _next_label: Label = get_node_or_null("%NextLabel")
@onready var _tier_bar: ProgressBar = get_node_or_null("%TierBar")


func _ready() -> void:
	custom_minimum_size.y = ROW_MIN_H
	add_theme_stylebox_override("panel", UiKit.inset(16, 8))
	_style_labels()
	_style_cost_button()
	if _tier_line != null:
		_tier_mark.setup(_tier_line, _mark_label, _next_label, _tier_bar)
	_tip.setup(self)
	_fx.button = _buy_button
	_buy_button.button_down.connect(_on_button_down)
	_buy_button.button_up.connect(_on_button_up)
	_buy_button.gui_input.connect(_on_button_input)
	visibility_changed.connect(_on_visibility_changed)
	tree_exiting.connect(_tip.queue_free)
	set_process(false)


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
	_tip.set_text(model.tooltip_text)
	if _tier_line != null:
		_tier_mark.apply(model)
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


## The VT-6 tier readout (tests).
func tier_mark() -> RowTierMark:
	return _tier_mark


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
	# only one of them to a row inside a ScrollContainer); `_tap_armed` makes the second source a no-op.
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_tap_changed(mb.pressed, mb.position)
		return
	var st: InputEventScreenTouch = event as InputEventScreenTouch
	if st != null:
		_tap_changed(st.pressed, st.position)
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_tap_moved(mm.position)
		return
	var sd: InputEventScreenDrag = event as InputEventScreenDrag
	if sd != null:
		_tap_moved(sd.position)


func _tap_changed(pressed: bool, pos: Vector2) -> void:
	if pressed:
		if not _tap_armed:
			_press_pos = pos
			_press_y = global_position.y
			_tap_armed = true
		return
	if not _tap_armed:
		return  # second source of the same release
	_tap_armed = false
	if pos.distance_to(_press_pos) > MOVE_CANCEL_PX or absf(global_position.y - _press_y) > SCROLL_CANCEL_PX:
		return  # a drag, not a tap
	toggle_tooltip()


func _tap_moved(pos: Vector2) -> void:
	if _tap_armed and pos.distance_to(_press_pos) > MOVE_CANCEL_PX:
		_tap_armed = false


## Tapping the row body shows the formula tooltip, tapping again (or waiting TOOLTIP_S) hides it.
func toggle_tooltip() -> void:
	if _tip.visible:
		_hide_tip()
		return
	_tip.open()


func _hide_tip() -> void:
	_tip.close()


func _on_visibility_changed() -> void:
	_stop_hold()
	if not visible:
		_hide_tip()


func _on_button_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		_ptr = mb.position
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_ptr = mm.position
	var sd: InputEventScreenDrag = event as InputEventScreenDrag
	if sd != null:
		_ptr = sd.position
	if _holding and _ptr.distance_to(_down_pos) > MOVE_CANCEL_PX:
		_stop_hold()


func _on_button_down() -> void:
	_hide_tip()
	_down_pos = _ptr
	_down_y = global_position.y
	_hold_s = 0.0
	_repeated = false
	_repeat.reset()
	_holding = true
	set_process(true)


func _on_button_up() -> void:
	var tap: bool = _holding and not _repeated
	if tap and absf(global_position.y - _down_y) > SCROLL_CANCEL_PX:
		tap = false
	_stop_hold()
	if tap:
		_request(1)


func _stop_hold() -> void:
	if _holding:
		AudioHooks.buy_end()  # release, cancel (drag, scroll, hidden) or a capped hold: the pitch streak ends
	_holding = false
	set_process(false)


func _process(delta: float) -> void:
	advance_hold(delta)


## Advances a held cost button by `delta` seconds (called per frame; tests call it directly).
func advance_hold(delta: float) -> void:
	if not _holding:
		set_process(false)
		return
	if absf(global_position.y - _down_y) > SCROLL_CANCEL_PX:
		_stop_hold()  # the list is scrolling under the finger
		return
	_hold_s += delta
	var due: Vector2i = _repeat.poll(_hold_s)
	if due.x == 0:
		return
	_repeated = true
	if _state != CostState.AFFORDABLE:
		_stop_hold()  # capped or out of scrap: the hold ends
		AudioHooks.deny()
		return
	for step: int in due.x:
		assert(step >= 0)
		_request(due.y)


func _request(count: int) -> void:
	if _state == CostState.AFFORDABLE:
		_fx.play_flash()
		AudioHooks.buy_step()
	else:
		AudioHooks.deny()
	buy_pressed.emit(_index, count)
