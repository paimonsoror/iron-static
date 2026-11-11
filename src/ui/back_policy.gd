class_name BackPolicy
extends RefCounted
## Decides what the Android back gesture does (V1-24, extended by M3-14). Pure: the caller reads the UI state, asks
## `decide` (battle) or `decide_screen` (any screen), then performs the returned action.
## Battle order (`decide`, the pause menu update): an open confirm (ABORT MISSION?) closes first, then the debug
## panel, then an open pause menu closes and RESUMES (back never quits from it), a running battle opens the pause
## menu, anything else quits.
## Per screen (`decide_screen`, a table, `SCREEN_ACTIONS`): an open debug panel closes first on every screen;
## SAVE_PROBLEM quits; HOME arms exit (first back shows `exit.back_again`, a second back within `EXIT_WINDOW_S`
## quits); FOUNDRY / SETTINGS / FRAME_BAY / SERVICE_RECORD go back to the opener; RESULTS goes HOME; COLD_OPEN skips
## (the screen consumes back); TITLE asks "QUIT?";
## an open confirm dialog (NEW GAME, Settings reset) closes first on every menu screen (CLOSE_DIALOG);
## BATTLE is `decide` unchanged.

enum Action { CLOSE_PANEL, PAUSE, QUIT, ARM_EXIT, GO_BACK, GO_HOME, CONFIRM_QUIT, CLOSE_DIALOG, RESUME }

## Seconds a first back on HOME keeps the exit armed.
const EXIT_WINDOW_S: float = 2.0

## Non-battle screens -> action (HOME is resolved with the armed flag, see `decide_screen`).
const SCREEN_ACTIONS: Dictionary = {
	AppFlow.Screen.SAVE_PROBLEM: Action.QUIT,
	AppFlow.Screen.HOME: Action.ARM_EXIT,
	AppFlow.Screen.FOUNDRY: Action.GO_BACK,
	AppFlow.Screen.SETTINGS: Action.GO_BACK,
	AppFlow.Screen.FRAME_BAY: Action.GO_BACK,
	AppFlow.Screen.RESULTS: Action.GO_HOME,
	AppFlow.Screen.TITLE: Action.CONFIRM_QUIT,
	AppFlow.Screen.COLD_OPEN: Action.GO_BACK,
	AppFlow.Screen.SERVICE_RECORD: Action.GO_BACK,
}


## Battle-only decision. `paused` = the pause menu is open; `dialog_open` = its ABORT MISSION confirm is open.
static func decide(panel_open: bool, paused: bool, in_battle: bool, dialog_open: bool = false) -> Action:
	if dialog_open:
		return Action.CLOSE_DIALOG
	if panel_open:
		return Action.CLOSE_PANEL
	if paused:
		return Action.RESUME
	if in_battle:
		return Action.PAUSE
	return Action.QUIT


## Decision for any screen. `exit_armed` = a previous back on HOME is still inside its 2 s window.
static func decide_screen(
	screen: AppFlow.Screen, panel_open: bool, paused: bool, in_battle: bool, exit_armed: bool, dialog_open: bool = false
) -> Action:
	if screen == AppFlow.Screen.BATTLE:
		return decide(panel_open, paused, in_battle, dialog_open)
	if dialog_open:
		return Action.CLOSE_DIALOG
	if panel_open:
		return Action.CLOSE_PANEL
	var action: Action = SCREEN_ACTIONS.get(screen, Action.QUIT)
	if screen == AppFlow.Screen.HOME and exit_armed:
		return Action.QUIT
	return action
