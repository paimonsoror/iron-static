class_name Fo1Frame
extends Node
## FO-1 desktop check: renders the Foundry with the explainer dialog open into SubViewports of the exact device
## sizes (1080x2400 phone, 1990x1920 foldable inner screen), normal and high contrast, plus the dialog closed.
## Needs a renderer (not --headless):
##   godot --path . --windowed res://src/debug/fo1_frame.tscn -- --no-save --mute [--fo1-out=<dir>]
## (default build/fo1)

const CASES: Array[Dictionary] = [
	{"name": "phone_1080x2400", "size": Vector2i(1080, 2400), "contrast": false, "open": true},
	{"name": "foldable_1990x1920", "size": Vector2i(1990, 1920), "contrast": false, "open": true},
	{"name": "phone_1080x2400_high_contrast", "size": Vector2i(1080, 2400), "contrast": true, "open": true},
	{"name": "phone_1080x2400_closed", "size": Vector2i(1080, 2400), "contrast": false, "open": false},
]
## Typical phone cutout and gesture bar (left, top, right, bottom).
const SAFE := Vector4(0.0, 110.0, 0.0, 70.0)

var _out: String = ""


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://build/fo1")
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--fo1-out="):
			_out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	for c: Dictionary in CASES:
		await _render(c)
	get_tree().quit()


func _render(c: Dictionary) -> void:
	var size: Vector2i = c["size"]
	var contrast: bool = c["contrast"]
	Game.visual.set_accessibility("off", contrast)
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size_2d_override_stretch = false
	add_child(vp)
	var profile: PlayerProfile = PlayerProfile.fresh(0, "fo1")
	profile.data = BigNum.from_int(640)
	profile.runs_total = 1
	var screen: FoundryScreen = (load("res://src/ui/foundry/foundry_screen.tscn") as PackedScene).instantiate()
	screen.use_profile(profile)
	screen.use_save_hooks(func() -> void: pass, func() -> bool: return true)
	vp.add_child(screen)
	screen.size = Vector2(size)
	screen.apply_safe_margins(SAFE)
	screen.enter()
	if not c["open"]:
		screen.intro.ok_button().pressed.emit()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var path: String = _out.path_join(str(c["name"]) + ".png")
	@warning_ignore("return_value_discarded")
	img.save_png(path)
	print("FO1 shot %s %dx%d" % [path, img.get_width(), img.get_height()])
	vp.queue_free()
	await get_tree().process_frame
