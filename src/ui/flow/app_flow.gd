class_name AppFlow
extends RefCounted
## Screen flow state machine (M3-14). Pure: no nodes, no autoloads; the router feeds it events and performs the
## screen swap. The flow is a DATA TABLE (`TABLE`): adding a screen or a transition is a table edit.
##
## Flow:  boot -> SAVE_PROBLEM (damaged or too-new save) | TITLE | (title off: BATTLE for a run snapshot, else HOME)
##        (`TITLE_ENABLED`: TITLE first, design 11; CONTINUE -> HOME, or BATTLE (the snapshot resumes, paused) while
##        `resume_pending`; NEW GAME -> FRAME_BAY (the router asks a confirm first
##        when the profile has progress), FRAME_BAY -confirm-> HOME, TITLE <-> SETTINGS,
##        SETTINGS -PROFILE_RESET-> TITLE); HOME -FRAMES-> FRAME_BAY (confirm and back both return to HOME: the
##        bay's back goes to its `OPENER`, TITLE after NEW GAME)
##        SAVE_PROBLEM -START_NEW-> HOME;  HOME -DEPLOY-> BATTLE;  HOME <-> FOUNDRY (after the first death) and
##        HOME <-> SETTINGS;  BATTLE -RUN_ENDED-> RESULTS;  RESULTS -DEPLOY-> BATTLE | -GO_HOME-> HOME |
##        -OPEN_FOUNDRY-> FOUNDRY;  FOUNDRY -DEPLOY-> BATTLE;  FOUNDRY and SETTINGS return to the screen they were
##        opened from (`OPENER`).

enum Screen { SAVE_PROBLEM, HOME, FOUNDRY, SETTINGS, BATTLE, RESULTS, TITLE, FRAME_BAY }
enum Event {
	DEPLOY,
	OPEN_FOUNDRY,
	OPEN_SETTINGS,
	BACK_TO_OPENER,
	GO_HOME,
	RUN_ENDED,
	START_NEW_PROFILE,
	CONTINUE,
	NEW_GAME,
	FRAME_CONFIRMED,
	FRAME_BAY_BACK,
	PROFILE_RESET,
	OPEN_FRAMES,
}

## Boot into the title screen (flipped on by M3-30).
const TITLE_ENABLED: bool = true
## Table value meaning "the screen this one was opened from".
const OPENER: int = -2
const NONE: int = -1

## screen -> {event -> target screen (or OPENER)}.
const TABLE: Dictionary = {
	Screen.SAVE_PROBLEM: {Event.START_NEW_PROFILE: Screen.HOME},
	Screen.TITLE: {Event.CONTINUE: Screen.HOME, Event.NEW_GAME: Screen.FRAME_BAY, Event.OPEN_SETTINGS: Screen.SETTINGS},
	Screen.FRAME_BAY: {Event.FRAME_CONFIRMED: Screen.HOME, Event.FRAME_BAY_BACK: OPENER},
	Screen.HOME:
	{
		Event.DEPLOY: Screen.BATTLE,
		Event.OPEN_FOUNDRY: Screen.FOUNDRY,
		Event.OPEN_SETTINGS: Screen.SETTINGS,
		Event.OPEN_FRAMES: Screen.FRAME_BAY,
	},
	Screen.FOUNDRY: {Event.DEPLOY: Screen.BATTLE, Event.BACK_TO_OPENER: OPENER},
	Screen.SETTINGS: {Event.BACK_TO_OPENER: OPENER, Event.PROFILE_RESET: Screen.TITLE},
	Screen.BATTLE: {Event.RUN_ENDED: Screen.RESULTS},
	Screen.RESULTS: {Event.DEPLOY: Screen.BATTLE, Event.GO_HOME: Screen.HOME, Event.OPEN_FOUNDRY: Screen.FOUNDRY},
}

## Screens that cover the whole view with a menu (the battle view and HUD are hidden).
const MENU_SCREENS: Array[Screen] = [
	Screen.SAVE_PROBLEM,
	Screen.HOME,
	Screen.FOUNDRY,
	Screen.SETTINGS,
	Screen.TITLE,
	Screen.FRAME_BAY,
]

var current: Screen = Screen.HOME
## Screen to return to from FOUNDRY / SETTINGS / FRAME_BAY.
var opener: Screen = Screen.HOME
## Set by the caller from `MetaUnlocks.foundry_screen_unlocked(profile)`.
var foundry_unlocked: bool = false
## Set by the caller from `Game.has_pending_resume()`: TITLE's CONTINUE then resumes the interrupted run.
var resume_pending: bool = false


## First screen. `save_problem` is `Game.save_problem != NONE`, `resumed` is a pending run snapshot. With the title
## on, a snapshot waits behind CONTINUE (design 11: boot -> TITLE, CONTINUE -> the resumed run, paused).
static func boot_screen(save_problem: bool, resumed: bool) -> Screen:
	if save_problem:
		return Screen.SAVE_PROBLEM
	if TITLE_ENABLED:
		return Screen.TITLE
	return Screen.BATTLE if resumed else Screen.HOME


static func is_menu(screen: AppFlow.Screen) -> bool:
	return MENU_SCREENS.has(screen)


## Where `event` would lead from the current screen, or NONE when illegal (including FOUNDRY while locked).
func target(event: AppFlow.Event) -> int:
	var row: Dictionary = TABLE.get(current, {})
	if not row.has(event):
		return NONE
	var to: int = row[event]
	if to == OPENER:
		to = opener
	if current == Screen.TITLE and event == Event.CONTINUE and resume_pending:
		to = Screen.BATTLE
	if to == Screen.FOUNDRY and not foundry_unlocked:
		return NONE
	return to


## Applies `event`: returns the new screen, or NONE (nothing changes) when the transition is illegal.
func apply(event: AppFlow.Event) -> int:
	var to: int = target(event)
	if to == NONE:
		return NONE
	enter(to as Screen)
	return to


## Forces the current screen (boot) and tracks the opener of FOUNDRY / SETTINGS / FRAME_BAY.
func enter(to: AppFlow.Screen) -> void:
	if to == Screen.FOUNDRY or to == Screen.SETTINGS or to == Screen.FRAME_BAY:
		opener = current
	current = to
