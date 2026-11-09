class_name SplashRender
extends Node
## Renders the boot splash PNG (desktop only): the static IRON STATIC title logo (shimmer shader, motion zeroed)
## centered on the game's void black, saved to assets/splash/splash.png, then quits:
##   godot --path . --windowed --resolution 540x600 res://src/debug/splash_render.tscn
## Re-run after the logo art changes. The image is shown at native size (project.godot `fullsize=false`).

const OUT: String = "res://assets/splash/splash.png"
const SIZE: Vector2i = Vector2i(900, 450)
const LOGO_SCALE: float = 0.85


func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = Palette.VOID
	bg.size = Vector2(SIZE)
	vp.add_child(bg)
	var logo := TitleLogo.new()
	vp.add_child(logo)
	logo.setup()
	logo.reduce_motion = true
	logo.tick(0.0, 0.0)
	logo.scale = Vector2.ONE * LOGO_SCALE
	logo.position = Vector2(SIZE) * 0.5
	for i: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/splash"))
	if img.save_png(ProjectSettings.globalize_path(OUT)) != OK:
		push_error("splash save failed")
	get_tree().quit()
