class_name DraftShots
extends Node
## Desktop capture harness of the patch draft overlay (M4-16). Renders the production `DraftOverlay` over a plain
## backdrop for a standard draft, a draft with a gamble card and picks so far, and the wide 1990 x 1920 layout, then
## saves PNGs and quits:
##   godot --path . --windowed --resolution 540x600 res://src/debug/draft_shots.tscn -- [--ds-out=build/m4_draft]

const SCENE: String = "res://src/ui/draft/draft_overlay.tscn"
const PORTRAIT: Vector2i = Vector2i(1080, 2400)
const WIDE: Vector2i = Vector2i(1990, 1920)


func _ready() -> void:
	var out: String = "build/m4_draft"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ds-out="):
			out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	await _shot(out, "standard", PORTRAIT, ["patch_overcharge", "patch_plating", "patch_rate"], {})
	await _shot(
		out,
		"gamble_picks",
		PORTRAIT,
		["patch_regen", "patch_t_greed", "patch_t_hardhide"],
		{"patch_overcharge": 2, "patch_plating": 1, "patch_t_glass": 1}
	)
	await _shot(out, "gamble_wide", WIDE, ["patch_extraction", "patch_t_glass", "patch_ceramic"], {"patch_rate": 3})
	get_tree().quit()


func _world(offer_ids: Array[String], picks: Dictionary[String, int]) -> SimWorld:
	var c := RunController.new()
	c.auto_pick_draft = false
	@warning_ignore("return_value_discarded")
	c.start_run(7, true)
	@warning_ignore("return_value_discarded")
	c.fast_forward(20 * Ticks.WAVE_TICKS)
	var w: SimWorld = c.world
	var ids: Array[String] = []
	for d: PatchDef in w.config.patches:
		ids.append(d.id)
	var offers := PackedInt32Array()
	for id: String in offer_ids:
		offers.append(ids.find(id))
	w.draft.offers = offers
	for id: String in picks:
		for n: int in picks[id]:
			@warning_ignore("return_value_discarded")
			w.patches.add(ids.find(id))
	return w


func _shot(
	out: String, shot_name: String, size: Vector2i, offer_ids: Array[String], picks: Dictionary[String, int]
) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var base := ColorRect.new()
	base.color = Palette.GRID
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(base)
	var overlay: DraftOverlay = (load(SCENE) as PackedScene).instantiate() as DraftOverlay
	overlay.reduce_motion = shot_name != "standard"  # the first shot catches the rings mid-flight
	vp.add_child(overlay)
	overlay.open(_world(offer_ids, picks))
	if not overlay.reduce_motion:
		overlay.advance(0.3)
	for i: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var plate: Control = overlay.get_child(2).get_child(0)
	print("[DRAFT] %s plate=%s screen=%s" % [shot_name, str(Rect2(plate.global_position, plate.size)), str(size)])
	var img: Image = vp.get_texture().get_image()
	if img.save_png(out.path_join("draft_%s.png" % shot_name)) != OK:
		push_error("draft shot save failed: " + shot_name)
	vp.queue_free()
	await get_tree().process_frame
