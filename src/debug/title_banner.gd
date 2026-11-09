class_name TitleBanner
extends RefCounted
## README banner capture (`--tf-banner[=dir]` on the title harness, desktop only). Renders the production title stage
## at its full 2160 x 2400 size with the button rows hidden, shrinks the logo and lowers it to sit just above Cinder,
## then crops the 2:1 band from the logo down to the ridge. Saves banner_full.png (the whole stage) and banner.jpg
## (1280 x 640, the README and codex banner), then quits. Re-run after title art changes:
##   godot --path . res://src/debug/title_frame.tscn -- --tf-banner=<dir> --mute

const STAGE: Vector2i = Vector2i(2160, 2400)
const SETTLE_S: float = 3.4
## Logo draw scale relative to the title screen's, and its center y on the stage (Cinder's head is near y 1200).
const LOGO_SHRINK: float = 0.7
const LOGO_Y: float = 905.0
## The 2:1 band on the stage: logo on top, Cinder, the hulks and the ridge below.
const CROP: Rect2i = Rect2i(0, 660, 2160, 1080)
const OUT_SIZE: Vector2i = Vector2i(1280, 640)
const JPG_QUALITY: float = 0.88


static func run(tf: TitleFrame, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = tf.get_tree()
	var vp: SubViewport = tf.host_viewport()
	var sc: TitleScreen = tf.screen()
	vp.size = STAGE
	sc.show_state(VisualQuality.Tier.HIGH, false, true, "vanguard")
	await tree.process_frame
	sc.buttons().visible = false
	var logo: TitleLogo = sc.logo()
	logo.scale *= LOGO_SHRINK
	logo.position.y = LOGO_Y
	await tree.create_timer(SETTLE_S).timeout
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var ok: bool = img.save_png(out.path_join("banner_full.png")) == OK
	var band: Image = img.get_region(CROP)
	band.resize(OUT_SIZE.x, OUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	ok = ok and band.save_jpg(out.path_join("banner.jpg"), JPG_QUALITY) == OK
	if not ok:
		push_error("banner save failed")
	tree.quit()
