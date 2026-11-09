class_name TitleFrameShots
extends RefCounted
## Desktop capture series and measurements of the production title screen (`--tf-shots[=dir]`, M3-28). Renders into
## the harness SubViewport (resized per shot), saves M3-28_*.png and a metrics.txt with the draw-call count per tier
## read from the rendering-info counter (fade finished), then quits.

const SETTLE_S: float = 3.4
const FRAMES: Array[String] = ["vanguard", "bulwark", "striker"]
const INSETS: Vector4 = Vector4(0.0, 110.0, 0.0, 70.0)

static var _lines: PackedStringArray = PackedStringArray()


static func run(tf: TitleFrame, out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree: SceneTree = tf.get_tree()
	var vp: SubViewport = tf.host_viewport()
	var sc: TitleScreen = tf.screen()
	var high: VisualQuality.Tier = VisualQuality.Tier.HIGH
	var low: VisualQuality.Tier = VisualQuality.Tier.LOW
	for fid: String in FRAMES:
		await _go(sc, vp, TitleFrame.PORTRAIT, high, false, true, fid)
		await _wait(tree, SETTLE_S)
		await _measure(sc, "high portrait, frame " + fid)
		await _save(vp, out, "M3-28_title_high_%s.png" % fid)
		await _go(sc, vp, TitleFrame.PORTRAIT, low, false, true, fid)
		await _wait(tree, SETTLE_S)
		await _measure(sc, "low portrait, frame " + fid)
		await _save(vp, out, "M3-28_title_low_%s.png" % fid)
		await _go(sc, vp, TitleFrame.WIDE, high, false, true, fid)
		await _wait(tree, SETTLE_S)
		await _measure(sc, "high wide 1990x1920, frame " + fid)
		await _save(vp, out, "M3-28_title_wide_%s.png" % fid)
	await _go(sc, vp, TitleFrame.PORTRAIT, VisualQuality.Tier.MID, false, true, "vanguard")
	await _wait(tree, SETTLE_S)
	await _measure(sc, "mid portrait")
	await _save(vp, out, "M3-28_title_mid.png")
	await _go(sc, vp, TitleFrame.PORTRAIT, high, true, false, "vanguard")
	await _wait(tree, SETTLE_S)
	await _measure(sc, "high portrait, reduce motion, no progress")
	await _save(vp, out, "M3-28_title_reduce_motion_new.png")
	await _go(sc, vp, Vector2(1080.0, 2341.0), high, false, true, "vanguard")
	sc.apply_safe_margins(INSETS)
	await _wait(tree, SETTLE_S)
	await _measure(sc, "high 1080x2341 with insets")
	await _save(vp, out, "M3-28_title_insets.png")
	sc.apply_safe_margins(Vector4.ZERO)
	await _go(sc, vp, TitleFrame.PORTRAIT, high, false, true, "vanguard")
	@warning_ignore("return_value_discarded")
	sc.on_back()
	await _wait(tree, 0.5)
	await _save(vp, out, "M3-28_title_quit.png")
	var f: FileAccess = FileAccess.open(out.path_join("metrics.txt"), FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	for l: String in _lines:
		print("[TITLE-METRIC] " + l)
	tree.quit()


## `continue_row` true shows the CONTINUE row (the main look); the quit confirm is closed first.
static func _go(
	sc: TitleScreen,
	vp: SubViewport,
	size: Vector2,
	t: VisualQuality.Tier,
	motion_off: bool,
	continue_row: bool,
	frame_id: String
) -> void:
	if sc.quit_box_visible():
		@warning_ignore("return_value_discarded")
		sc.on_back()
	vp.size = Vector2i(size)
	sc.show_state(t, motion_off, continue_row, frame_id)
	await sc.get_tree().process_frame


static func _wait(tree: SceneTree, secs: float) -> void:
	await tree.create_timer(secs).timeout
	await RenderingServer.frame_post_draw


static func _measure(sc: TitleScreen, label: String) -> void:
	await RenderingServer.frame_post_draw
	var draws: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var fx: TitleFx = sc.fx()
	var msg: String = "%s: draws=%d smoke=%d embers_live=%d tex_mb=%.1f"
	_lines.append(msg % [label, draws, fx.visible_smoke_count(), fx.ember_count(), _texture_mb(fx.frame_id_shown())])


static func _texture_mb(frame_id: String) -> float:
	var names: Array[String] = []
	names.append_array(TitleArt.LAYER_NAMES)
	names.append_array(["logo", "sil_" + frame_id, "sil_" + frame_id + "_glow"])
	var total: float = 0.0
	for n: String in names:
		var t: Texture2D = TitleArt.tex(n)
		total += float(t.get_width() * t.get_height() * 4)
	return total / 1048576.0


static func _save(vp: SubViewport, out: String, file: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var err: Error = img.save_png(out.path_join(file))
	if err != OK:
		push_error("save failed: " + file)
