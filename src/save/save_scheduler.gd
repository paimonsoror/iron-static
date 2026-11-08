class_name SaveScheduler
extends RefCounted
## Pure save cadence (TECH_ARCHITECTURE 5.3, M3-12): a save request is debounced 2 s, a menu autosaves every
## 60 s, and a run checkpoint is due every 30 s of unpaused run time. No clock: the caller feeds `dt`.
## `advance` returns bit flags (FLAG_SAVE, FLAG_CHECKPOINT) and the caller does the writing.

const FLAG_SAVE: int = 1
const FLAG_CHECKPOINT: int = 2
const DEBOUNCE_S: float = 2.0
const MENU_AUTOSAVE_S: float = 60.0
const CHECKPOINT_S: float = 30.0

var _pending: bool = false
var _debounce_left: float = 0.0
var _menu_time: float = 0.0
var _run_time: float = 0.0


## A state change wants a save: it fires DEBOUNCE_S after the FIRST request of a burst.
func request_save() -> void:
	if not _pending:
		_pending = true
		_debounce_left = DEBOUNCE_S


func is_pending() -> bool:
	return _pending


## Call after any successful write (the menu timer restarts, a pending request is satisfied).
func notify_saved() -> void:
	_pending = false
	_menu_time = 0.0


## A checkpoint was just written (the 30 s interval restarts).
func notify_checkpointed() -> void:
	_run_time = 0.0


func advance(dt: float, in_menu: bool, in_run: bool, paused: bool = false) -> int:
	var flags: int = 0
	if _pending:
		_debounce_left -= dt
		if _debounce_left <= 0.0:
			_pending = false
			_menu_time = 0.0
			flags |= FLAG_SAVE
	if in_menu:
		_menu_time += dt
		if _menu_time >= MENU_AUTOSAVE_S:
			_menu_time = 0.0
			flags |= FLAG_SAVE
	else:
		_menu_time = 0.0
	if in_run and not paused:
		_run_time += dt
		if _run_time >= CHECKPOINT_S:
			_run_time = 0.0
			flags |= FLAG_CHECKPOINT
	elif not in_run:
		_run_time = 0.0
	return flags
