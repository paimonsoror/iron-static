class_name FrameBay
extends MenuScreen
## Frame bay (M3-29, design 11 section 3): a carousel of the listed frames (VANGUARD, BULWARK, STRIKER) with the
## stat comparison against the selected frame, the lock condition and progress, and SELECT / CONTINUE / BACK.
## Signals are final: `confirmed` (the selected frame was accepted: NEW GAME continues to Home) and `back_pressed`.
## Selecting persists at once (`Game.saves.request_save()`); a locked frame only plays the deny sound.

signal confirmed
signal back_pressed

const SWIPE_PX: float = 120.0
const DOT_PX: float = 26.0
const NAV_W: float = 148.0

var _defs: Array[FrameDef] = []
var _foundry: FoundryService
var _cards: Array[FrameCard] = []
var _index: int = 0
var _card_view: FrameCardView
var _dots: HBoxContainer
var _prev: Button
var _next: Button
var _action: Button
var _back: Button
var _press_x: float = -1.0


func title_key() -> String:
	return "frame.bay_title"


func _build() -> void:
	_defs = FrameRules.load_defs()
	_foundry = FoundryService.new(SimConfigLoader.load_foundry_defs(), SimConfigLoader.load_default(1).upgrades)
	content.add_theme_constant_override("separation", 24)
	_card_view = FrameCardView.new()
	_card_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_card_view)
	content.add_child(_build_nav())
	_action = make_button("frame.select", _on_action)
	content.add_child(_action)
	_back = make_button("foundry.back", _on_back)
	content.add_child(_back)


func _build_nav() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_prev = _nav_button("<", -1)
	row.add_child(_prev)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.add_theme_constant_override("separation", 22)
	row.add_child(_dots)
	_next = _nav_button(">", 1)
	row.add_child(_next)
	return row


func _nav_button(text: String, step: int) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = ThemeBuilder.VAR_BUTTON_PLATE
	b.custom_minimum_size = Vector2(NAV_W, float(ThemeBuilder.TOUCH_MIN_HEIGHT))
	b.add_theme_font_size_override("font_size", BUTTON_FONT_PX)
	b.add_theme_color_override("font_color", Palette.AMBER_GLOW)
	b.pressed.connect(_on_nav.bind(step))
	return b


## Rebuilds the cards from the profile and shows the selected frame.
func enter() -> void:
	_refresh(true)
	# autowrap labels report a huge minimum height before their first layout, which grows `content` past the column
	_layout()
	_layout.call_deferred()


## Index of the frame shown (carousel position).
func shown_index() -> int:
	return _index


func shown_card() -> FrameCard:
	return _cards[_index] if _index < _cards.size() else null


func card_view() -> FrameCardView:
	return _card_view


func action_button() -> Button:
	return _action


func prev_button() -> Button:
	return _prev


func next_button() -> Button:
	return _next


func back_button() -> Button:
	return _back


## Moves the carousel by `step` (wraps).
func page(step: int) -> void:
	if _cards.is_empty():
		return
	_index = FrameBayModel.wrap_index(_index, step, _cards.size())
	_show()


func _refresh(reset_index: bool) -> void:
	if Game.saves == null:
		return
	var profile: PlayerProfile = Game.profile()
	# Always compare against VANGUARD (the reference frame); comparing to the selected frame made it read 0% everywhere.
	_cards = FrameRules.cards(profile, _defs, _foundry, "vanguard")
	if reset_index:
		_index = FrameBayModel.index_of(_cards, FrameRules.selected_id(profile, _defs))
	_index = clampi(_index, 0, maxi(_cards.size() - 1, 0))
	_show()


func _show() -> void:
	var card: FrameCard = shown_card()
	if card == null:
		return
	_card_view.bind(card)
	_action.text = FrameBayModel.action_text(card)
	var locked: bool = card.locked
	_action.theme_type_variation = (ThemeBuilder.VAR_BUTTON_UNAFFORDABLE if locked else ThemeBuilder.VAR_BUTTON_PLATE)
	if locked:
		_action.remove_theme_color_override("font_color")
	else:
		_action.add_theme_color_override("font_color", Palette.AMBER_GLOW)
	for c: Node in _dots.get_children():
		c.queue_free()
		_dots.remove_child(c)
	for i: int in _cards.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(DOT_PX, DOT_PX)
		dot.color = Palette.AMBER if i == _index else Palette.UNAFFORDABLE
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_dots.add_child(dot)


func _on_nav(step: int) -> void:
	AudioHooks.tap()
	page(step)


func _on_action() -> void:
	var card: FrameCard = shown_card()
	if card == null:
		return
	match FrameBayModel.action_of(card):
		FrameBayModel.Action.LOCKED:
			AudioHooks.deny()
		FrameBayModel.Action.SELECT:
			AudioHooks.tap()
			if FrameRules.select(Game.profile(), card.id):
				Game.saves.request_save()
				_refresh(false)
		_:
			AudioHooks.tap()
			confirmed.emit()


func _on_back() -> void:
	AudioHooks.tap()
	back_pressed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_press_x = mb.position.x
		elif _press_x >= 0.0:
			var dx: float = mb.position.x - _press_x
			_press_x = -1.0
			if absf(dx) >= SWIPE_PX:
				AudioHooks.tap()
				page(-1 if dx > 0.0 else 1)
