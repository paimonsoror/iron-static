class_name BackPolicy
extends RefCounted
## Decides what the Android back gesture does (V1-24). Pure: the caller reads the UI state, asks `decide`, then
## performs the returned action. Order: close the topmost panel, a paused game quits, a finished run quits (nothing
## to pause), a running battle pauses.

enum Action { CLOSE_PANEL, PAUSE, QUIT }


static func decide(panel_open: bool, paused: bool, in_battle: bool) -> Action:
	if panel_open:
		return Action.CLOSE_PANEL
	if paused:
		return Action.QUIT
	if in_battle:
		return Action.PAUSE
	return Action.QUIT
