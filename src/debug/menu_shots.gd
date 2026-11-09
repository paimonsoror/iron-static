class_name MenuShots
extends Node
## Desktop capture harness of the menu screens (side-margin pass): renders Home (fresh profile), the Frame Bay, the
## Foundry and Settings into SubViewports and saves PNGs, then quits:
##   godot --path . --windowed --resolution 540x600 res://src/debug/menu_shots.tscn -- [--ms-out=build/m4_polish]

const PORTRAIT: Vector2i = Vector2i(1080, 2400)
const WIDE: Vector2i = Vector2i(1990, 1920)


func _ready() -> void:
	var out: String = "build/m4_polish"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ms-out="):
			out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	await _shot(out, "home", "res://src/ui/home/home_screen.tscn", PORTRAIT)
	await _shot(out, "home_wide", "res://src/ui/home/home_screen.tscn", WIDE)
	await _shot(out, "frame_bay", "res://src/ui/frames/frame_bay.tscn", PORTRAIT)
	await _shot(out, "foundry", "res://src/ui/foundry/foundry_screen.tscn", PORTRAIT)
	await _shot(out, "settings", "res://src/ui/settings/settings_screen.tscn", PORTRAIT)
	await _shot(out, "title", "res://src/ui/title/title_screen.tscn", PORTRAIT)
	await _dialog(out)
	get_tree().quit()


func _viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var base := ColorRect.new()
	base.color = Palette.VOID
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(base)
	return vp


func _save(vp: SubViewport, out: String, shot_name: String) -> void:
	for i: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	if img.save_png(out.path_join("menu_%s.png" % shot_name)) != OK:
		push_error("menu shot save failed: " + shot_name)
	vp.queue_free()
	await get_tree().process_frame


func _shot(out: String, shot_name: String, scene: String, size: Vector2i) -> void:
	var vp: SubViewport = _viewport(size)
	var s: MenuScreen = (load(scene) as PackedScene).instantiate() as MenuScreen
	if s is HomeScreen:
		(s as HomeScreen).setup(PlayerProfile.fresh(0, "shots"))
	vp.add_child(s)
	s.size = Vector2(size)
	s.enter()
	await _save(vp, out, shot_name)


func _dialog(out: String) -> void:
	var vp: SubViewport = _viewport(PORTRAIT)
	var d := ConfirmDialog.new()
	vp.add_child(d)
	d.size = Vector2(PORTRAIT)
	d.open("ABORT MISSION?", "This ends the run and banks what you earned.", "ABORT", "CANCEL")
	await _save(vp, out, "confirm")
