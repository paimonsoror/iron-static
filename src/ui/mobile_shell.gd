class_name MobileShell
extends Node
## Android platform glue owned by the main scene (V1-24, TECH_ARCHITECTURE "Mobile platform rules"): the back
## gesture, app lifecycle and the safe area. Pausing only ever means "no ticks" (`RunController.paused`): sim state
## is never touched, so determinism holds. Decisions live in `BackPolicy` and `SafeArea` (pure, tested).
## Pause menu (RESUME / ABORT MISSION / EXIT GAME, `PauseOverlay`): the first back, the HUD pause button, the app
## going to the background and a resumed run all open it. Back: close the ABORT MISSION confirm, else the debug
## panel, else an open menu closes and resumes, else a running battle opens the menu (`BackPolicy.decide`).
## ABORT MISSION (confirmed) banks the run like a death and goes Home (`AbortMission`); EXIT GAME flushes the
## profile and run snapshot, then quits (so CONTINUE resumes the run).
## Lifecycle: APPLICATION_PAUSED / FOCUS_OUT (mobile builds only; desktop focus changes must not pause benches)
## open the menu; coming back stays paused until the player picks RESUME.
## M3 NOTE: the save system must persist on NOTIFICATION_APPLICATION_PAUSED (write synchronously, atomic temp file
## plus rename). Android may kill a backgrounded process with no further callback. `Game._notification` does it (M3-12).

## Pause on app pause / focus loss. Defaults to mobile builds; tests flip it.
var lifecycle_enabled: bool = OS.has_feature("mobile")
## Apply the OS safe area to the HUD. Defaults to mobile builds (desktop: window is the safe area).
var safe_area_enabled: bool = OS.has_feature("mobile")

## Calls `get_tree().quit()` on EXIT GAME / a back with nothing to close (tests turn it off and count).
var quits_tree: bool = true
var exit_count: int = 0
## Flushed (profile, then the run checkpoint) just before EXIT GAME quits; main.gd hands it `Game.saves`.
var saves: SaveService = null

var _controller: RunController = null
var _hud: Hud = null
var _results: Control = null
var _debug: Control = null
var _overlay: PauseOverlay = null
var _router: ScreenRouter = null


## M3-14: hands the screen router in. On every screen except BATTLE the back gesture goes through it
## (`BackPolicy.decide_screen`); BATTLE keeps the V1-24 behavior exactly. Safe margins also reach its screens.
func set_router(router: ScreenRouter) -> void:
	_router = router
	refresh_safe_area()


## Wires the shell to the main scene's parts and adds the pause overlay as a child (topmost when added last).
func setup(controller: RunController, hud: Hud, results: Control, debug: Control) -> void:
	_controller = controller
	_hud = hud
	_results = results
	_debug = debug
	_overlay = PauseOverlay.new()
	add_child(_overlay)
	_overlay.resume_requested.connect(resume)
	_overlay.abort_requested.connect(abort_mission)
	_overlay.exit_requested.connect(exit_game)
	get_viewport().size_changed.connect(refresh_safe_area)
	refresh_safe_area()


func overlay() -> PauseOverlay:
	return _overlay


## True while a battle is running (a finished run shows the results overlay instead).
func in_battle() -> bool:
	return _controller.state == RunController.State.IN_RUN and not _results.visible


## Performs the back action for the current UI state and returns it.
func handle_back() -> BackPolicy.Action:
	if _router != null and _router.current_screen() != AppFlow.Screen.BATTLE:
		var screen_action: BackPolicy.Action = _router.handle_back(_debug.visible)
		if screen_action == BackPolicy.Action.CLOSE_PANEL:
			_debug.hide()
		return screen_action
	var action: BackPolicy.Action = BackPolicy.decide(
		_debug.visible, _overlay.visible, in_battle(), _overlay.confirm_open()
	)
	match action:
		BackPolicy.Action.CLOSE_DIALOG:
			@warning_ignore("return_value_discarded")
			_overlay.cancel_confirm()
		BackPolicy.Action.CLOSE_PANEL:
			_debug.hide()
		BackPolicy.Action.RESUME:
			resume()
		BackPolicy.Action.PAUSE:
			pause()
		BackPolicy.Action.QUIT:
			exit_game()
	return action


## Stops ticking, mirrors the state on the HUD button, shows the pause menu and pauses audio.
func pause() -> void:
	_controller.paused = true
	_hud.set_paused(true)
	_overlay.show()
	_set_audio_paused(true)


func resume() -> void:
	_close_menu()
	AudioHooks.tap()


## EXIT GAME: saves like the old second back (profile, then the run snapshot) and quits. CONTINUE on the title
## then resumes the run.
func exit_game() -> void:
	if saves != null:
		saves.flush_for_background()
	exit_count += 1
	if quits_tree and is_inside_tree():
		get_tree().quit()


## ABORT MISSION confirmed: the menu closes, the run is banked as a death, the app goes Home (see `AbortMission`).
func abort_mission() -> void:
	_close_menu()
	@warning_ignore("return_value_discarded")
	AbortMission.run(_controller, _router)


func _close_menu() -> void:
	_controller.paused = false
	_hud.set_paused(false)
	_overlay.hide()
	_overlay.set_notice("")
	_set_audio_paused(false)


## The app went to the background or lost focus. A running battle pauses behind the overlay.
func on_app_suspended() -> void:
	if lifecycle_enabled and in_battle():
		pause()


## Recomputes the HUD margins from the OS safe area (also on every viewport size change: fold, rotate).
func refresh_safe_area() -> void:
	if not safe_area_enabled or _hud == null:
		return
	var win := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var m: Vector4 = SafeArea.margins(win, safe, get_viewport().get_visible_rect().size)
	_hud.apply_safe_margins(m)
	if _router != null:
		_router.apply_safe_margins(m)


func _notification(what: int) -> void:
	if _controller == null:
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		@warning_ignore("return_value_discarded")
		handle_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		on_app_suspended()


## Freezes every voice and the music while paused (AudioDirector.pause_all / resume_all; idempotent).
func _set_audio_paused(paused: bool) -> void:
	if paused:
		AudioHooks.pause_audio()
	else:
		AudioHooks.resume_audio()
