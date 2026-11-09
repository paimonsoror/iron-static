class_name ScreenRouter
extends Control
## Screen router (M3-14): shows exactly one full-screen screen at a time and owns the flow between them
## (`AppFlow`, pure). Sibling nodes of the main scene (BattleView, Hud, ResultsOverlay) are handed in by
## `setup`; while a MENU screen is up they are `visible = false`, `set_process(false)` and
## `process_mode = DISABLED`, so a menu costs no render. BATTLE and RESULTS show them (the results overlay is
## owned by main.gd/M3-17 and stays an overlay on the battle).
##
## REGISTRATION API (for screen authors; nobody edits main.gd):
##   1. Implement your screen as a scene whose root script `extends MenuScreen` (`flow/menu_screen.gd`), in your
##      own folder, with the signals the M3-14 stub declares (signal names are final).
##   2. The screen -> scene -> signal-to-event table is `ScreenRegistry.ENTRIES` (data). The router loads it in
##      `register_defaults()`. `register(screen, scene_path, signals)` adds or replaces one entry at runtime:
##      `signals` maps a signal name (no args) to an `AppFlow.Event`; emitting it makes the router apply the event
##      (`AppFlow.TABLE` decides the target; illegal events are ignored).
##   3. A new screen or transition = add an `AppFlow.Screen` value, rows in `AppFlow.TABLE`, an entry in
##      `ScreenRegistry.ENTRIES`, and (if it handles back) a row in `BackPolicy.SCREEN_ACTIONS`.
## Screens get safe margins, `enter()` when shown, `leave()` when hidden. Entering BATTLE through DEPLOY calls
## `Game.start_run()` (a pending resume starts instead, paused); menus call `Game.audio.start_menu_audio()`, BATTLE
## `stop_menu_audio()`. The router owns the `exit.back_again` toast and the one-shot notice toast (`Game.notice`).

signal screen_changed(screen: AppFlow.Screen)
## Emitted after a BATTLE entry started or resumed a run (main.gd shows the PAUSED overlay when the controller is
## paused, i.e. a resumed run).
signal battle_entered

const TOAST_S: float = 2.0
const NOTICE_S: float = 3.5

## Calls `get_tree().quit()` on QUIT (tests turn it off and watch `quit_requested`).
var quits_tree: bool = true
var flow: AppFlow = AppFlow.new()
var quit_requested_count: int = 0

var _controller: RunController = null
var _battle: CanvasItem = null
var _hud: CanvasItem = null
var _results: CanvasItem = null
var _entries: Dictionary = {}
var _screens: Dictionary = {}
var _active: MenuScreen = null
var _safe := Vector4.ZERO
var _toast: PanelContainer = null
var _toast_label: Label = null
var _toast_token: int = 0
var _exit_armed_until_ms: int = 0


## Wires the router to the main scene. `battle`, `hud` and `results` are the sibling views it hides on menus.
func setup(controller: RunController, battle: CanvasItem, hud: CanvasItem, results: CanvasItem) -> void:
	_controller = controller
	_battle = battle
	_hud = hud
	_results = results
	theme = ThemeBuilder.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_toast()
	register_defaults()
	_controller.run_ended.connect(_on_run_ended)


func register_defaults() -> void:
	for e: Dictionary in ScreenRegistry.ENTRIES:
		var screen: AppFlow.Screen = e["screen"]
		var scene: String = e["scene"]
		var sigs: Dictionary = e["signals"]
		register(screen, scene, sigs)


## Adds or replaces the scene and signal map of `screen` (see the file header). Drops a cached instance.
func register(screen: AppFlow.Screen, scene_path: String, signals: Dictionary) -> void:
	_entries[screen] = {"scene": scene_path, "signals": signals}
	if _screens.has(screen):
		var old: MenuScreen = _screens[screen]
		if old == _active:
			_active = null
		old.queue_free()
		@warning_ignore("return_value_discarded")
		_screens.erase(screen)


func current_screen() -> AppFlow.Screen:
	return flow.current


## The live screen node of the current menu screen, null while BATTLE or RESULTS is up.
func active_screen() -> MenuScreen:
	return _active


## Boots into the first screen (`AppFlow.boot_screen`). `start_run` false keeps BATTLE without starting a run
## (debug load: the caller already started it).
func boot(start_run: bool = true) -> void:
	refresh_unlocks()
	var screen: AppFlow.Screen = AppFlow.boot_screen(
		Game.save_problem != SaveService.Problem.NONE, Game.has_pending_resume()
	)
	flow.enter(screen)
	_present(screen, start_run and screen == AppFlow.Screen.BATTLE, AppFlow.Screen.HOME)


## Shows BATTLE without starting a run (the debug load already started one).
func show_battle() -> void:
	flow.enter(AppFlow.Screen.BATTLE)
	_present(AppFlow.Screen.BATTLE, false, AppFlow.Screen.HOME)


## Applies a flow event. False (nothing changes) when the transition is illegal from the current screen.
func dispatch(event: AppFlow.Event) -> bool:
	refresh_unlocks()
	var from: AppFlow.Screen = flow.current
	var to: int = flow.apply(event)
	if to == AppFlow.NONE:
		return false
	_present(to as AppFlow.Screen, to == AppFlow.Screen.BATTLE and event == AppFlow.Event.DEPLOY, from)
	return true


func refresh_unlocks() -> void:
	flow.foundry_unlocked = Game.saves != null and MetaUnlocks.foundry_screen_unlocked(Game.profile())


## The back gesture on a non-battle screen: decides with `BackPolicy.decide_screen` and performs it. A returned
## CLOSE_PANEL is left to the caller (MobileShell hides the debug panel).
func handle_back(panel_open: bool) -> BackPolicy.Action:
	var armed: bool = Time.get_ticks_msec() < _exit_armed_until_ms
	var paused: bool = _controller != null and _controller.paused
	var action: BackPolicy.Action = BackPolicy.decide_screen(flow.current, panel_open, paused, false, armed)
	match action:
		BackPolicy.Action.ARM_EXIT:
			_exit_armed_until_ms = Time.get_ticks_msec() + int(BackPolicy.EXIT_WINDOW_S * 1000.0)
			show_toast(Strings.get_text("exit.back_again"), TOAST_S)
		BackPolicy.Action.QUIT:
			_quit()
		BackPolicy.Action.GO_BACK:
			if not _active_consumes_back():
				@warning_ignore("return_value_discarded")
				dispatch(
					(
						AppFlow.Event.BACK_TO_OPENER
						if flow.current != AppFlow.Screen.FRAME_BAY
						else AppFlow.Event.FRAME_BAY_BACK
					)
				)
		BackPolicy.Action.GO_HOME:
			@warning_ignore("return_value_discarded")
			dispatch(AppFlow.Event.GO_HOME)
		BackPolicy.Action.CONFIRM_QUIT:
			@warning_ignore("return_value_discarded")
			_active_consumes_back()
	return action


## Margins from `SafeArea` (left, top, right, bottom), applied to every screen and the toast.
func apply_safe_margins(m: Vector4) -> void:
	_safe = m
	for s: MenuScreen in _screens.values():
		s.apply_safe_margins(m)
	_toast.offset_top = m.y + 24.0


## Shows a one-line toast for `seconds`.
func show_toast(text: String, seconds: float) -> void:
	_toast_label.text = text
	_toast.show()
	_toast_token += 1
	var token: int = _toast_token
	get_tree().create_timer(seconds).timeout.connect(_on_toast_timeout.bind(token))


func toast_visible() -> bool:
	return _toast != null and _toast.visible


func toast_text() -> String:
	return _toast_label.text if _toast_label != null else ""


## Returns `Game.notice` and clears it (the caller decides where to show it); "" when none.
func take_notice() -> String:
	var key: String = Game.notice
	Game.notice = ""
	return Strings.get_text(key) if key != "" else ""


## Shows the pending notice as a toast (menu screens); returns whether one was shown.
func show_notice_toast() -> bool:
	var text: String = take_notice()
	if text == "":
		return false
	show_toast(text, NOTICE_S)
	return true


func _present(screen: AppFlow.Screen, start_run: bool, from: AppFlow.Screen) -> void:
	if _active != null:
		_active.leave()
		_active.hide()
		_active.process_mode = Node.PROCESS_MODE_DISABLED
		_active = null
	if AppFlow.is_menu(screen):
		_set_battle_visible(false)
		if _results.has_method(&"hide_results"):
			_results.call(&"hide_results")  # also stops the tally animation
		else:
			_results.hide()
		_active = _screen_node(screen)
		if _active != null:
			_active.process_mode = Node.PROCESS_MODE_INHERIT
			_active.apply_safe_margins(_safe)
			_active.show()
			_active.enter()
		Game.audio.start_menu_audio()
	else:
		_set_battle_visible(true)
		if screen == AppFlow.Screen.BATTLE:
			Game.audio.stop_menu_audio()
			if start_run:
				Game.start_run()
				battle_entered.emit()
		elif AppFlow.is_menu(from):
			_results.show()  # back from the Foundry: the results overlay was hidden behind the menu
	screen_changed.emit(screen)


func _set_battle_visible(on: bool) -> void:
	for n: CanvasItem in [_battle, _hud]:
		n.visible = on
		n.set_process(on)
		n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _screen_node(screen: AppFlow.Screen) -> MenuScreen:
	if _screens.has(screen):
		return _screens[screen]
	if not _entries.has(screen):
		Log.warn("[ROUTER] no screen registered for %s" % AppFlow.Screen.keys()[screen])
		return null
	var entry: Dictionary = _entries[screen]
	var path: String = entry["scene"]
	var scene: PackedScene = load(path)
	var node: MenuScreen = scene.instantiate() as MenuScreen
	add_child(node)
	move_child(node, 0)  # the toast stays on top
	var sigs: Dictionary = entry["signals"]
	for sig_name: StringName in sigs:
		if node.has_signal(sig_name):
			@warning_ignore("return_value_discarded")
			node.connect(sig_name, _on_screen_signal.bind(sigs[sig_name]))
		else:
			Log.warn("[ROUTER] %s has no signal %s" % [path, sig_name])
	if node.has_signal(&"quit_confirmed"):
		@warning_ignore("return_value_discarded")
		node.connect(&"quit_confirmed", _quit)
	_screens[screen] = node
	node.hide()
	return node


func _on_screen_signal(event: int) -> void:
	@warning_ignore("return_value_discarded")
	dispatch(event as AppFlow.Event)


@warning_ignore("unused_parameter")
func _on_run_ended(world: SimWorld) -> void:  # gdlint: ignore=unused-argument
	@warning_ignore("return_value_discarded")
	dispatch(AppFlow.Event.RUN_ENDED)


func _active_consumes_back() -> bool:
	return _active != null and _active.on_back()


func _quit() -> void:
	quit_requested_count += 1
	if quits_tree and is_inside_tree():
		get_tree().quit()


func _on_toast_timeout(token: int) -> void:
	if token == _toast_token:
		_toast.hide()


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.theme_type_variation = &"PanelPlate"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 24.0
	_toast_label = Label.new()
	_toast_label.theme_type_variation = &"LabelNumber"
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.add_theme_color_override("font_color", Palette.AMBER_GLOW)
	_toast_label.add_theme_font_size_override("font_size", 44)
	_toast.add_child(_toast_label)
	_toast.hide()
	add_child(_toast)
