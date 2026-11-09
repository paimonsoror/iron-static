class_name ScreenRegistry
extends RefCounted
## The screen table (M3-14): which scene shows which `AppFlow.Screen` and which of its signals raise which
## `AppFlow.Event`. Data only. A wave-3b screen author implements their own scene and script and the signals named
## here; this file and `main.gd` stay untouched. `ScreenRouter.register` takes the same three fields.

const ENTRIES: Array[Dictionary] = [
	{
		"screen": AppFlow.Screen.SAVE_PROBLEM,
		"scene": "res://src/ui/flow/save_problem_screen.tscn",
		"signals": {&"resolved": AppFlow.Event.START_NEW_PROFILE},
	},
	{
		"screen": AppFlow.Screen.HOME,
		"scene": "res://src/ui/home/home_screen.tscn",
		"signals":
		{
			&"deploy_pressed": AppFlow.Event.DEPLOY,
			&"foundry_pressed": AppFlow.Event.OPEN_FOUNDRY,
			&"settings_pressed": AppFlow.Event.OPEN_SETTINGS,
		},
	},
	{
		"screen": AppFlow.Screen.FOUNDRY,
		"scene": "res://src/ui/foundry/foundry_screen.tscn",
		"signals": {&"deploy_pressed": AppFlow.Event.DEPLOY, &"back_pressed": AppFlow.Event.BACK_TO_OPENER},
	},
	{
		"screen": AppFlow.Screen.SETTINGS,
		"scene": "res://src/ui/settings/settings_screen.tscn",
		"signals": {&"back_pressed": AppFlow.Event.BACK_TO_OPENER, &"profile_reset": AppFlow.Event.PROFILE_RESET},
	},
	{
		"screen": AppFlow.Screen.TITLE,
		"scene": "res://src/ui/title/title_screen.tscn",
		"signals":
		{
			&"continue_pressed": AppFlow.Event.CONTINUE,
			&"new_game_pressed": AppFlow.Event.NEW_GAME,
			&"settings_pressed": AppFlow.Event.OPEN_SETTINGS,
		},
	},
	{
		"screen": AppFlow.Screen.FRAME_BAY,
		"scene": "res://src/ui/frames/frame_bay.tscn",
		"signals": {&"confirmed": AppFlow.Event.FRAME_CONFIRMED, &"back_pressed": AppFlow.Event.FRAME_BAY_BACK},
	},
]
