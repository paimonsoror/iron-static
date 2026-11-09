class_name HomeScreen
extends MenuScreen
## Home (M3-15, GDD 07 section 2.3 for the MVP): the place the player returns to and redeploys from. Heading and
## gear, a PR plate and the data balance, the diorama (arena floor and Cinder at rest), best wave, sector and the
## selected frame, the next-unlock hint, a Foundry hint chip when something is affordable, DEPLOY and the nav.
## Locked and not-yet-existing items (Foundry before the first death, flux, cipher, merit, Standby, ads) are
## hidden, not grayed. Signals are final: deploy_pressed, foundry_pressed, settings_pressed, frames_pressed (the
## frame chip, opens the frame bay). Menu screens never
## tick the sim: everything is read from `Game.profile()` (or the profile given to `setup`).

signal deploy_pressed
signal foundry_pressed
signal settings_pressed
signal frames_pressed
signal mode_selected(id: String)

const TOP_ROW_H: float = 148.0
const HEADING_PX: int = 72
const DEPLOY_H: float = 200.0
const DEPLOY_PX: int = 84
const CHIP_PX: int = 44
const NUMBER_PX: int = 54
const BEST_PX: int = 64
const ICON_PX: float = 64.0
const GEAR_PAD: float = 8.0
const PULSE_HZ: float = 0.8
const PULSE_AMOUNT: float = 0.22
const HOME_SEPARATION: int = 28
const FOOT_PAD: float = 16.0
const MIN_ARENA_GAP: float = 240.0

var nav_foundry: Button
var deploy_button: Button
var gear_button: Button
var hint_chip: Button
var nav_home: Button
var nav_row: HBoxContainer
var pr_label: Label
var data_label: Label
var best_label: Label
var sector_label: Label
var frame_button: Button
var mode_picker: ModePicker
var hint_label: Label
var diorama: HomeDiorama
var model: HomeModel = null
## Reduce motion for the DEPLOY pulse (the diorama reads `Game.visual` itself); tests set it directly.
var reduce_motion: bool = false

var _profile: PlayerProfile = null
var _upgrades: Array[RunUpgradeDef] = []
var _foundry: FoundryService = null
var _frame_defs: Array[FrameDef] = []
var _spacer: Control = null
var _t: float = 0.0


func title_key() -> String:
	return "home.header"


## Optional: show a given profile instead of `Game.profile()` (tests, captures). Call before or after adding.
func setup(profile: PlayerProfile) -> void:
	_profile = profile
	if content != null:
		refresh()


func _build() -> void:
	_upgrades = SimConfigLoader.load_default(1).upgrades
	_foundry = FoundryService.new(SimConfigLoader.load_foundry_defs(), _upgrades)
	_frame_defs = FrameRules.load_defs()
	content.add_theme_constant_override("separation", HOME_SEPARATION)
	diorama = HomeDiorama.new()
	add_child(diorama)
	move_child(diorama, 1)  # above the background fill, below the content
	heading.add_theme_font_size_override("font_size", HEADING_PX)
	heading.custom_minimum_size = Vector2(0.0, TOP_ROW_H)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(_stat_strip())
	_spacer = Control.new()
	_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_spacer.custom_minimum_size = Vector2(0.0, MIN_ARENA_GAP)
	_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_spacer)
	content.add_child(_info_panel())
	frame_button = _plate_button("", _on_frames, ThemeBuilder.VAR_BUTTON_PLATE, CHIP_PX)
	content.add_child(frame_button)
	hint_chip = _plate_button("", _on_foundry, ThemeBuilder.VAR_BUTTON_AFFORDABLE, CHIP_PX)
	content.add_child(hint_chip)
	mode_picker = ModePicker.new()
	mode_picker.mode_selected.connect(_on_mode_selected)
	content.add_child(mode_picker)
	deploy_button = _plate_button(
		Strings.get_text("home.deploy"), _on_deploy, ThemeBuilder.VAR_BUTTON_AFFORDABLE, DEPLOY_PX
	)
	deploy_button.custom_minimum_size = Vector2(0.0, DEPLOY_H)
	deploy_button.add_theme_font_override("font", heading.get_theme_font("font", ThemeBuilder.VAR_LABEL_HEADING))
	content.add_child(deploy_button)
	content.add_child(_nav())
	var foot := Control.new()  # breathing room under the nav (the OS inset comes on top of it)
	foot.custom_minimum_size = Vector2(0.0, FOOT_PAD)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(foot)
	gear_button = Button.new()
	gear_button.custom_minimum_size = Vector2(TOP_ROW_H, TOP_ROW_H)
	UiKit.style_icon_button(gear_button, "icon_ic_settings")
	gear_button.pressed.connect(_on_settings)
	add_child(gear_button)
	content.sort_children.connect(_on_sorted)
	enter()


## Refreshes every field from the profile each time the screen is shown.
func enter() -> void:
	if content == null or deploy_button == null:
		return
	refresh()
	_t = 0.0
	set_process(true)


func leave() -> void:
	set_process(false)
	_consume_unlock_chip()


func refresh() -> void:
	var p: PlayerProfile = _profile if _profile != null else Game.profile()
	model = HomeModel.build(p, _upgrades, _foundry, _frame_defs)
	pr_label.text = model.pr_text
	data_label.text = model.data_text
	best_label.text = model.best_text
	best_label.add_theme_color_override("font_color", Palette.AMBER if model.best_known else Palette.TEXT_DIM)
	sector_label.text = model.sector_text
	frame_button.text = model.frame_button_text
	frame_button.visible = model.frame_button_visible
	hint_label.text = model.hint_text
	hint_chip.text = model.foundry_hint_text
	hint_chip.visible = model.hint_chip_visible()
	nav_foundry.visible = model.foundry_visible
	nav_row.visible = model.nav_visible()
	diorama.set_frame(model.frame_id)
	mode_picker.setup(model.mode_cards, model.selected_mode)
	if not model.unlock_chip_text.is_empty():
		mode_picker.show_info(model.unlock_chip_text)


func _process(delta: float) -> void:
	_t += delta
	diorama.tick(delta)
	var pulse: float = 0.0 if (reduce_motion or Game.visual.reduce_motion) else _pulse(_t)
	deploy_button.self_modulate = Color(1.0 + pulse, 1.0 + pulse * 0.7, 1.0 + pulse * 0.3, 1.0)


## 0..PULSE_AMOUNT sine pulse of the DEPLOY glow.
static func _pulse(t: float) -> float:
	return PULSE_AMOUNT * (0.5 - 0.5 * cos(t * TAU * PULSE_HZ))


func _layout() -> void:
	super()
	if gear_button == null:
		return
	var r: Rect2 = column_rect()
	gear_button.position = Vector2(r.end.x - TOP_ROW_H - GEAR_PAD, r.position.y)


func _on_sorted() -> void:
	# A first pass with a still-unwrapped label can leave the VBox taller than the column: pin it back.
	var col: Rect2 = column_rect()
	if content.size.y > col.size.y + 0.5 and content.get_combined_minimum_size().y <= col.size.y:
		content.set_deferred("size", col.size)
	var r := Rect2(_spacer.global_position - global_position, _spacer.size)
	var radius: float = clampf(minf(r.size.x * 0.28, r.size.y * 0.30), 80.0, 230.0)
	diorama.place(r.get_center(), radius)


func _stat_strip() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var pr_plate: PanelContainer = _plate()
	pr_label = _number_label(Palette.AMBER)
	pr_plate.add_child(pr_label)
	pr_plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pr_plate)
	var data_plate: PanelContainer = _plate()
	var inner := HBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 16)
	inner.add_child(UiKit.icon_rect("icon_cur_data", ICON_PX))
	data_label = _number_label(Palette.DATA)
	data_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner.add_child(data_label)
	data_plate.add_child(inner)
	data_plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(data_plate)
	return row


func _info_panel() -> Control:
	var plate: PanelContainer = _plate()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	best_label = label("", &"LabelHeading", Palette.AMBER, BEST_PX)
	box.add_child(best_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	sector_label = label("", &"LabelDim", Palette.TEXT_DIM, ThemeBuilder.FONT_SIZE_BODY)
	sector_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(sector_label)
	box.add_child(row)
	hint_label = label("", &"LabelDim", Palette.TEXT_DIM, ThemeBuilder.FONT_SIZE_BODY)
	box.add_child(hint_label)
	plate.add_child(box)
	return _bracketed(plate)


func _nav() -> HBoxContainer:
	nav_row = HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 24)
	nav_home = _plate_button(Strings.get_text("nav.home"), Callable(), ThemeBuilder.VAR_BUTTON_CHIP_ACTIVE, CHIP_PX)
	nav_home.mouse_filter = Control.MOUSE_FILTER_IGNORE  # the active tab: nothing to do, no sound
	nav_home.focus_mode = Control.FOCUS_NONE
	nav_foundry = _plate_button(Strings.get_text("nav.foundry"), _on_foundry, ThemeBuilder.VAR_BUTTON_PLATE, CHIP_PX)
	for b: Button in [nav_home, nav_foundry]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav_row.add_child(b)
	return nav_row


func _plate() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = ThemeBuilder.VAR_PANEL_PLATE
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _number_label(color: Color) -> Label:
	var l: Label = label("", &"LabelNumber", color, NUMBER_PX)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## A full-width plate button (touch target >= 148 px); `on_pressed` may be invalid for a button that does nothing.
func _plate_button(text: String, on_pressed: Callable, variation: StringName, size_px: int) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(0.0, float(ThemeBuilder.TOUCH_MIN_HEIGHT))
	b.add_theme_font_size_override("font_size", size_px)
	b.add_theme_color_override("font_color", Palette.AMBER_GLOW)
	if on_pressed.is_valid():
		b.pressed.connect(on_pressed)
	return b


## Wraps `plate` in a plain Control that follows its minimum size and draws the amber corner brackets (art bible 7.1).
func _bracketed(plate: PanelContainer) -> Control:
	var host := Control.new()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(plate)
	UiKit.add_brackets(host, 2.0)
	var sync_min := func() -> void: host.custom_minimum_size = plate.get_combined_minimum_size()
	plate.minimum_size_changed.connect(sync_min)
	sync_min.call()
	return host


## The chip shows once: leaving Home clears the flag (saved with the next profile save).
func _consume_unlock_chip() -> void:
	var p: PlayerProfile = _profile if _profile != null else Game.profile()
	if p != null and ModeUnlockFlag.clear(p) and _profile == null:
		Game.saves.request_save()


## A segment was chosen: remember it as `last_mode` (Q75) so DEPLOY and REDEPLOY repeat it.
func _on_mode_selected(id: String) -> void:
	AudioHooks.tap()
	var p: PlayerProfile = _profile if _profile != null else Game.profile()
	if p.select_mode(id) and _profile == null:
		Game.saves.request_save()
	best_label.text = HomeModel.best_line(p, id)
	best_label.add_theme_color_override(
		"font_color", Palette.AMBER if p.best_wave_of_mode(id, 1) > 0 else Palette.TEXT_DIM
	)
	mode_selected.emit(id)


func _on_deploy() -> void:
	AudioHooks.tap()
	deploy_pressed.emit()


func _on_foundry() -> void:
	AudioHooks.tap()
	foundry_pressed.emit()


func _on_settings() -> void:
	AudioHooks.tap()
	settings_pressed.emit()


func _on_frames() -> void:
	AudioHooks.tap()
	frames_pressed.emit()
