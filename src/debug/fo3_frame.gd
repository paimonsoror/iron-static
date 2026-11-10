class_name Fo3Frame
extends Node
## FO-3 / R1-02 desktop check: renders the Foundry with rows over the best-wave soft cap (the "x3 COST UNTIL
## WAVE N" line and the over-limit cost color) and the FO-1 explainer with its new last line, into a SubViewport
## of the exact phone size (1080x2400), normal contrast. Needs a renderer (not --headless):
##   godot --path . --windowed res://src/debug/fo3_frame.tscn -- --no-save --mute [--fo3-out=<dir>]
## (default build/fo3)

const SIZE := Vector2i(1080, 2400)
## Typical phone cutout and gesture bar (left, top, right, bottom).
const SAFE := Vector4(0.0, 110.0, 0.0, 70.0)

var _out: String = ""


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://build/fo3")
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fo3-out="):
			_out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	await _render("over_limit_row_1080x2400", false)
	await _render("explainer_1080x2400", true)
	get_tree().quit()


func _render(shot_name: String, show_intro: bool) -> void:
	Game.visual.set_accessibility("off", false)
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size_2d_override_stretch = false
	add_child(vp)
	var profile: PlayerProfile = PlayerProfile.fresh(0, "fo3")
	profile.data = BigNum.from_int(640)
	profile.runs_total = 3
	profile.best_wave["1"] = 10  # soft cap 6: laser and hull are over it (x3 cost), cycle and nano are below it
	profile.set_foundry_level("laser_output", 6)
	profile.set_foundry_level("hull_integrity", 6)
	profile.set_foundry_level("cycle_rate", 2)
	profile.set_foundry_level("nano_repair", 3)
	@warning_ignore("return_value_discarded")
	FoundryIntroFlag.set_hidden(profile, not show_intro)
	var screen: FoundryScreen = (load("res://src/ui/foundry/foundry_screen.tscn") as PackedScene).instantiate()
	screen.use_profile(profile)
	screen.use_save_hooks(func() -> void: pass, func() -> bool: return true)
	vp.add_child(screen)
	screen.size = Vector2(SIZE)
	screen.apply_safe_margins(SAFE)
	screen.enter()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var path: String = _out.path_join(shot_name + ".png")
	@warning_ignore("return_value_discarded")
	img.save_png(path)
	print("FO3 shot %s %dx%d" % [path, img.get_width(), img.get_height()])
	vp.queue_free()
	await get_tree().process_frame
