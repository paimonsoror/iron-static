class_name TitleFrameShots
extends RefCounted
## Desktop capture series and measurements of the title style frame (`--tf-shots[=dir]`). Renders into the frame's
## SubViewport (resized per shot), saves M3-25_*.png and a metrics.txt with the draw-call count per tier read from
## the rendering-info counter (menu hidden, fade finished), then quits.

const SETTLE_S: float = 3.4

static var _lines: PackedStringArray = PackedStringArray()


static func run(tf: TitleFrame, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = tf.get_tree()
	var vp: SubViewport = tf.host_viewport()
	await _go(tf, vp, TitleFrame.PORTRAIT, VisualQuality.Tier.HIGH, false, true)
	await _wait(tree, SETTLE_S)
	await _measure(tf, "high portrait")
	await _save(vp, out, "M3-25_title_high.png")
	await _crop_logo(vp, tf, out, "M3-25_logo_closeup.png")
	tf.stage().start_flare()
	await _wait(tree, 0.2)
	await _measure(tf, "high portrait during a flare")
	await _save(vp, out, "M3-25_title_flare.png")
	await _wait(tree, 1.0)
	tf.set_state(VisualQuality.Tier.HIGH, false, false)
	await _wait(tree, 0.3)
	await _measure(tf, "high portrait, scanlines off")
	await _go(tf, vp, TitleFrame.PORTRAIT, VisualQuality.Tier.MID, false, false)
	await _wait(tree, SETTLE_S)
	await _measure(tf, "mid portrait")
	await _save(vp, out, "M3-25_title_mid.png")
	await _go(tf, vp, TitleFrame.PORTRAIT, VisualQuality.Tier.LOW, false, false)
	await _wait(tree, SETTLE_S)
	await _measure(tf, "low portrait")
	await _save(vp, out, "M3-25_title_low.png")
	await _go(tf, vp, TitleFrame.PORTRAIT, VisualQuality.Tier.HIGH, true, true)
	await _wait(tree, SETTLE_S)
	await _measure(tf, "high portrait, reduce motion")
	await _save(vp, out, "M3-25_title_reduce_motion.png")
	await _go(tf, vp, TitleFrame.PORTRAIT, VisualQuality.Tier.HIGH, false, true)
	await _wait(tree, SETTLE_S)
	await _glitch(tf, vp, tree, out)
	await _go(tf, vp, TitleFrame.WIDE, VisualQuality.Tier.HIGH, false, true)
	await _wait(tree, SETTLE_S)
	await _measure(tf, "high wide 1990x1920")
	await _save(vp, out, "M3-25_title_wide.png")
	_lines.append("texture memory of the title sheets (RGBA8): %.1f MB" % _sheet_mb())
	var f: FileAccess = FileAccess.open(out.path_join("metrics.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	for l: String in _lines:
		print("[TITLE-METRIC] " + l)
	tree.quit()


static func _go(
	tf: TitleFrame, vp: SubViewport, size: Vector2, t: VisualQuality.Tier, motion_off: bool, scan: bool
) -> void:
	vp.size = Vector2i(size)
	tf.layout(size)
	tf.set_state(t, motion_off, scan)
	await tf.get_tree().process_frame


static func _wait(tree: SceneTree, secs: float) -> void:
	await tree.create_timer(secs).timeout
	await RenderingServer.frame_post_draw


static func _measure(tf: TitleFrame, label: String) -> void:
	await RenderingServer.frame_post_draw
	var draws: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var st: TitleFrameStage = tf.stage()
	var fps: float = Engine.get_frames_per_second()
	var msg: String = "%s: draws=%d smoke=%d embers_live=%d fps(desktop)=%.0f"
	_lines.append(msg % [label, draws, st.visible_smoke_count(), st.ember_count(), fps])


static func _save(vp: SubViewport, out: String, file: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var err: Error = img.save_png(out.path_join(file))
	if err != OK:
		push_error("save failed: " + file)


static func _crop_logo(vp: SubViewport, tf: TitleFrame, out: String, file: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var lp: Vector2 = tf.logo().position
	var r := Rect2i(Vector2i(int(lp.x) - 480, int(lp.y) - 240), Vector2i(960, 480))
	var crop: Image = img.get_region(r)
	crop.resize(1920, 960, Image.INTERPOLATE_LANCZOS)
	var err: Error = crop.save_png(out.path_join(file))
	if err != OK:
		push_error("save failed: " + file)


static func _glitch(tf: TitleFrame, vp: SubViewport, tree: SceneTree, out: String) -> void:
	for attempt: int in 12:
		tf.logo().force_tear()
		await tree.process_frame
		await tree.process_frame
		if tf.logo().is_tearing():
			await RenderingServer.frame_post_draw
			await _crop_logo(vp, tf, out, "M3-25_logo_glitch.png")
			await _save(vp, out, "M3-25_title_glitch.png")
			return
		await _wait(tree, 0.4)
	push_error("could not catch a glitch frame")


static func _sheet_mb() -> float:
	var total: float = 0.0
	for n: String in TitleFrameArt.LAYER_NAMES + ["logo", "sil_vanguard", "sil_vanguard_glow"]:
		var t: Texture2D = TitleFrameArt.tex(n)
		total += float(t.get_width() * t.get_height() * 4)
	return total / 1048576.0
