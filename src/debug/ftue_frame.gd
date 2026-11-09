class_name FtueFrame
extends Node
## M4-26 desktop check: boots the real main scene on a fresh in-memory profile, walks NEW GAME -> frame bay ->
## cold open -> run 1 and saves screenshots of the cold open (lines, Cinder) and of the FTUE pointers and labels.
## Needs a window:
##   godot --path . --windowed --resolution 540x960 res://src/debug/ftue_frame.tscn -- --no-save --mute
##   [--ftue-out=<dir>]   (default build/m4_ftue)

var _out: String = ""
var _main: Control = null


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://build/m4_ftue")
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ftue-out="):
			_out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	_main = (load("res://src/ui/main.tscn") as PackedScene).instantiate()
	add_child(_main)
	await _wait(0.8)
	var router: ScreenRouter = _find(ScreenRouter)
	var overlay: FtueOverlay = _find(FtueOverlay)
	(router.active_screen() as TitleScreen).new_game_pressed.emit()
	await _wait(0.3)
	(router.active_screen() as FrameBay).confirmed.emit()
	await _wait(2.8)
	_shot("1_cold_open_lines")
	await _wait(2.9)
	_shot("2_cold_open_cinder")
	(router.active_screen() as ColdOpen).skip()
	await _wait(1.0)
	_shot("3_run1_pointer_laser_output")
	Game.request_buy(0, 1)
	await _wait(0.4)
	var dart: int = 1
	Game.controller.world.events.push(SimEventKind.ENEMY_SPAWNED, 0, dart)
	await _wait(0.6)
	_shot("4_run1_dart_label")
	overlay.state.complete("dart_label")
	Game.controller.world.events.push(SimEventKind.CINDER_HIT, 3, 0)
	await _wait(0.8)
	_shot("5_run1_hull_tab_pointer")
	Game.controller.world.end_run()
	await _wait(2.5)
	_shot("6_results_foundry_hint")
	Game.profile().data = BigNum.from_float(500.0)
	(_find(ResultsOverlay) as ResultsOverlay).foundry_pressed.emit()
	await _wait(1.2)
	_shot("7_foundry_row_hint")
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _find(type: Variant) -> Node:
	for c: Node in _main.get_children():
		if is_instance_of(c, type):
			return c
	return null


func _shot(shot_name: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = _out.path_join(shot_name + ".png")
	@warning_ignore("return_value_discarded")
	img.save_png(path)
	print("FTUE shot %s %dx%d" % [path, img.get_width(), img.get_height()])
