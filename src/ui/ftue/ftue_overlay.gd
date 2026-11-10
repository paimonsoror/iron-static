class_name FtueOverlay
extends Control
## The FTUE pointer and label layer (M4-26). Sits above the HUD and the router screens, below the draft and the
## pause overlay, and ignores input (`mouse_filter` IGNORE) so taps pass straight through; only the SKIP HINTS button
## takes touches. It draws the active beat of its `FtueState`: a `FtuePointer` on the target rect (a run upgrade row,
## the Results FOUNDRY button, a Foundry row) and a label plate with the beat's text, or just the plate for
## `field` targets. Silent beats draw nothing. A beat shows only on its own screen (`shown_on`) and expires by itself
## (`FtueState.DISPLAY_S`); nothing ever blocks play.
##
## Wiring (main.gd): `target_resolver` maps a target string to a GLOBAL rect (Rect2() when unknown), `persist` writes
## the state back to the profile, `start_run(world, profile)` on each run start, `set_screen` on each screen change,
## `on_results_shown()` / `on_foundry_opened()` for the UI events.

signal skipped

const PLATE_FONT_PX: int = 40
const SKIP_FONT_PX: int = 38
const SKIP_MIN_W: float = 260.0
const FIELD_Y_FRAC: float = 0.235

## Set true to force reduce motion (it is also read from `Game.visual.reduce_motion`).
var reduce_motion: bool = false:
	set(value):
		reduce_motion = value
		if _pointer != null:
			_pointer.reduce_motion = value

var state: FtueState = null
var target_resolver: Callable = Callable()
var persist: Callable = Callable()
## Maps a target string to the GLOBAL rect its plate sits next to (`FtueTargets.anchor`); optional.
var anchor_resolver: Callable = Callable()
## Optional `() -> bool`: true while a dialog covers the screen (the Foundry explainer); the beat waits, unaged.
var blocker: Callable = Callable()

var _screen: AppFlow.Screen = AppFlow.Screen.HOME
var _world: SimWorld = null
var _watcher: FtueWatcher = FtueWatcher.new()
var _pointer: FtuePointer = null
var _plate: PanelContainer = null
var _label: Label = null
var _skip: Button = null
var _shown_id: String = ""


func _ready() -> void:
	theme = ThemeBuilder.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer = FtuePointer.new()
	_pointer.reduce_motion = reduce_motion
	add_child(_pointer)
	_plate = PanelContainer.new()
	_plate.theme_type_variation = ThemeBuilder.VAR_PANEL_PLATE
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(row)
	_label = Label.new()
	_label.theme_type_variation = ThemeBuilder.VAR_LABEL_HEADING
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Palette.AMBER_GLOW)
	_label.add_theme_font_size_override("font_size", PLATE_FONT_PX)
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_label)
	_skip = Button.new()
	_skip.theme_type_variation = ThemeBuilder.VAR_BUTTON_PLATE
	_skip.text = Strings.get_text("ftue.skip")
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.custom_minimum_size = Vector2(SKIP_MIN_W, float(ThemeBuilder.TOUCH_MIN_HEIGHT))
	_skip.add_theme_font_size_override("font_size", SKIP_FONT_PX)
	_skip.pressed.connect(_on_skip)
	row.add_child(_skip)
	_hide_all()
	set_process(false)


## Only beats of a screen show: run upgrade rows and `field` labels in BATTLE, the FOUNDRY pulse on RESULTS, a
## Foundry row in FOUNDRY.
static func shown_on(target: String, screen: AppFlow.Screen) -> bool:
	if target == FtueScript.TARGET_RESULTS_FOUNDRY:
		return screen == AppFlow.Screen.RESULTS
	if target.begins_with(FtueScript.FOUNDRY_PREFIX):
		return screen == AppFlow.Screen.FOUNDRY
	if target == FtueScript.TARGET_FIELD or target.begins_with(FtueScript.ROW_PREFIX):
		return screen == AppFlow.Screen.BATTLE
	return false


## Loads the FTUE state of `profile`, starts its run `runs_total + 1` and watches `world`.
func start_run(world: SimWorld, profile: PlayerProfile) -> void:
	_world = world
	state = FtueState.load_from(FtueScript.load_default(), profile)
	@warning_ignore("return_value_discarded")
	state.begin_run(profile.runs_total)
	_watcher.bind(world)
	_after_change()


func set_screen(screen: AppFlow.Screen) -> void:
	_screen = screen
	_sync()


## The Results screen appeared: the FOUNDRY button beat starts.
func on_results_shown() -> void:
	if state != null:
		state.drop_pending()
		@warning_ignore("return_value_discarded")
		state.on_event(FtueScript.RESULTS_FIRST)
		_after_change()


## The player opened the Foundry: the FOUNDRY pulse is done and the Foundry beat starts.
func on_foundry_opened() -> void:
	if state == null:
		return
	@warning_ignore("return_value_discarded")
	state.complete("results_foundry")
	@warning_ignore("return_value_discarded")
	state.on_event(FtueScript.FOUNDRY_FIRST)
	_after_change()


## True while the Results FOUNDRY button should pulse.
func foundry_pulse_wanted() -> bool:
	var beat: FtueBeatDef = _shown_beat()
	return beat != null and beat.target == FtueScript.TARGET_RESULTS_FOUNDRY


func label_text() -> String:
	return _label.text if _label != null else ""


func is_hint_visible() -> bool:
	return _plate != null and _plate.visible


func pointer() -> FtuePointer:
	return _pointer


func skip_button() -> Button:
	return _skip


## Presses SKIP HINTS (tests).
func skip_all() -> void:
	_on_skip()


func _process(delta: float) -> void:
	if state == null:
		return
	_watcher.update(state)
	if _shown_beat() != null:
		state.advance(delta)
	_after_change()


func _after_change() -> void:
	if state != null and state.dirty and persist.is_valid():
		persist.call()
	_sync()
	set_process(state != null and state.enabled())


## The active beat when it is drawn on the current screen, else null.
func _shown_beat() -> FtueBeatDef:
	if state == null:
		return null
	var beat: FtueBeatDef = state.active()
	if beat == null or FtueScript.is_silent(beat) or not shown_on(beat.target, _screen):
		return null
	if blocker.is_valid() and blocker.call():
		return null
	return beat


func _sync() -> void:
	if _plate == null:
		return
	var beat: FtueBeatDef = _shown_beat()
	if beat == null:
		_hide_all()
		return
	if beat.id != _shown_id:
		_shown_id = beat.id
		_label.text = Strings.get_text(beat.text_key)
	_plate.show()
	_plate.size = _plate.get_combined_minimum_size()
	var rect: Rect2 = _target_rect(beat)
	if rect.size == Vector2.ZERO:
		_pointer.clear()
		_plate.position = Vector2((size.x - _plate.size.x) * 0.5, size.y * FIELD_Y_FRAC)
		return
	var kind: FtuePlacement.Kind = FtuePlacement.kind_of(beat.target)
	_pointer.point_at(rect, FtuePlacement.arrow_from_above(kind), FtuePlacement.arrow_x(kind, rect))
	_plate.position = FtuePlacement.plate_pos(kind, rect, _anchor_rect(beat), _plate.size, size, UiKit.MENU_SIDE_MARGIN)


## The beat's target in this control's coordinates; Rect2() when it has none or the resolver does not know it.
func _target_rect(beat: FtueBeatDef) -> Rect2:
	if beat.target == FtueScript.TARGET_FIELD or not target_resolver.is_valid():
		return Rect2()
	var global: Rect2 = target_resolver.call(beat.target)
	if global.size == Vector2.ZERO:
		return Rect2()
	return Rect2(global.position - global_position, global.size)


## The rect the plate goes next to (see `FtuePlacement`), in this control's coordinates; Rect2() when unknown.
func _anchor_rect(beat: FtueBeatDef) -> Rect2:
	if not anchor_resolver.is_valid():
		return Rect2()
	var global: Rect2 = anchor_resolver.call(beat.target)
	if global.size == Vector2.ZERO:
		return Rect2()
	return Rect2(global.position - global_position, global.size)


func _hide_all() -> void:
	_shown_id = ""
	if _plate != null:
		_plate.hide()
	if _pointer != null:
		_pointer.clear()


func _on_skip() -> void:
	if state == null:
		return
	state.skip_all()
	_after_change()
	skipped.emit()
