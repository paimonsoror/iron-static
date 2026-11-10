class_name DraftOverlay
extends Control
## The patch draft overlay (07 s2.9, M4-16): a 60% dim over the frozen battle, one plate with the title
## ("WAVE 5 CLEARED", M4-27), the first-draft note, three `DraftCard`s (gamble cards: dashed amber border, benefit and
## cost) and the picks so far, then a REROLL ALL button (R1-04: one reroll per draft redraws all three cards).
## `open(world)` shows it for the open draft; a completed tap on a card calls
## `world.command_pick(slot)`, closes, plays the pick sound and emits `picked(slot)` (main.gd turns that into the
## haptic pulse). It runs from an input event, so the pick always lands between frames, never inside
## `TickDriver.advance`. No timer, no auto-pick. Back and the pause menu are handled by `MobileShell` (the pause
## overlay is a later child, so it draws over this one). `vfx_draft_open` (`DraftOpenFx`) is two amber rings drawn in
## wall time under the cards; reduce motion skips the rings and the card fade.

signal picked(slot: int)

## Plate width in base px (side margins of `UiKit.MENU_SIDE_MARGIN` on the 1080 reference).
const PLATE_W: float = 1080.0 - 2.0 * UiKit.MENU_SIDE_MARGIN
const DIM_ALPHA: float = 0.6
const SLOTS: int = 3
const REROLL_H: float = 156.0

## Set true to force reduce motion (it is also read from `Game.visual.reduce_motion`).
var reduce_motion: bool = false

var _world: SimWorld = null
var _model: DraftModel = null
var _open: bool = false
var _t: float = 0.0
var _title: Label = null
var _note: Label = null
var _picks: Label = null
var _reroll: Button = null
var _cards: Array[DraftCard] = []
var _plate: PanelContainer = null
var _fx: Control = null


func _ready() -> void:
	theme = ThemeBuilder.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(Palette.VOID, DIM_ALPHA)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_plate = PanelContainer.new()
	_plate.custom_minimum_size = Vector2(PLATE_W, 0.0)
	_plate.theme_type_variation = ThemeBuilder.VAR_PANEL_PLATE
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(column)
	_title = _label(ThemeBuilder.VAR_LABEL_HEADING, Palette.AMBER, 72)
	column.add_child(_title)
	_note = _label(ThemeBuilder.VAR_LABEL_NUMBER, Palette.TEXT_DIM, 40)
	column.add_child(_note)
	for i: int in SLOTS:
		var item := DraftCard.new()
		item.chosen.connect(_on_card_chosen)
		column.add_child(item)
		_cards.append(item)
	_reroll = Button.new()
	_reroll.custom_minimum_size = Vector2(0.0, REROLL_H)
	_reroll.add_theme_font_size_override("font_size", 48)
	_reroll.pressed.connect(_on_reroll_pressed)
	column.add_child(_reroll)
	_picks = _label(ThemeBuilder.VAR_LABEL_NUMBER, Palette.TEXT_DIM, 38)
	column.add_child(_picks)
	set_process(false)


## Shows the overlay for the draft that is open in `world` (a no-op when none is). Safe to call again.
func open(world: SimWorld) -> void:
	if world == null or not world.is_draft_open():
		return
	_world = world
	_populate()
	_t = 0.0
	var was_open: bool = _open
	_open = true
	show()
	_apply_fx()
	set_process(true)
	if not was_open:
		AudioHooks.draft_open()


## Fills the title, cards, picks line and reroll button from the open draft (also after a reroll).
func _populate() -> void:
	_model = DraftModel.from_world(_world)
	_title.text = _model.title()
	_note.text = _model.note()
	_note.visible = _note.text != ""
	_picks.text = _model.picks_line()
	_picks.visible = _picks.text != ""
	for i: int in SLOTS:
		var has: bool = i < _model.cards.size()
		_cards[i].visible = has
		if has:
			_cards[i].set_data(_model.cards[i])
	_reroll.text = _model.reroll_text()
	_reroll.disabled = not _model.can_reroll()
	_reroll.theme_type_variation = (
		ThemeBuilder.VAR_BUTTON_PLATE if _model.can_reroll() else ThemeBuilder.VAR_BUTTON_UNAFFORDABLE
	)


## Hides the overlay without picking (a run ending or aborting behind it).
func close() -> void:
	_open = false
	_world = null
	hide()
	set_process(false)


func is_open() -> bool:
	return _open


func model() -> DraftModel:
	return _model


func reroll_button() -> Button:
	return _reroll


func card(i: int) -> DraftCard:
	return _cards[i]


## Advances the open effect by `delta` seconds (`_process` calls this; tests may too).
func advance(delta: float) -> void:
	_t += delta
	_apply_fx()
	if _t >= DraftOpenFx.total_s():
		set_process(false)


func _process(delta: float) -> void:
	advance(delta)


func _reduced() -> bool:
	return reduce_motion or Game.visual.reduce_motion


func _apply_fx() -> void:
	var reduced: bool = _reduced()
	_plate.modulate.a = DraftOpenFx.card_fade(_t, reduced)
	if _fx != null:
		_fx.queue_redraw()


func _draw_fx() -> void:
	if not _open:
		return
	var c: Vector2 = size * 0.5
	for i: int in DraftOpenFx.ring_count(_reduced()):
		var p: float = DraftOpenFx.progress(i, _t)
		var a: float = DraftOpenFx.alpha(p)
		if a > 0.0:
			_fx.draw_arc(c, DraftOpenFx.radius(p), 0.0, TAU, 96, Color(Palette.AMBER, a), DraftOpenFx.WIDTH_PX, true)


## Rerolls all cards once per draft. Runs from an input event, so it lands between frames.
func _on_reroll_pressed() -> void:
	if not _open or _world == null:
		return
	if _world.command_reroll():
		_populate()


func _on_card_chosen(slot: int) -> void:
	if not _open or _world == null:
		return
	if not _world.command_pick(slot):
		return
	close()
	AudioHooks.draft_pick()
	picked.emit(slot)


## Swallows every touch the plate and the cards do not take: tapping the dim does nothing.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		accept_event()


static func _label(variation: StringName, color: Color, size_px: int) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size_px)
	return l
