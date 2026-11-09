class_name VtRowShots
extends Node
## Desktop capture harness of the VT-6 upgrade row marks. Hosts the production `UpgradePanel` over a plain backdrop
## with chosen run levels and saves PNGs, then quits:
##   godot --path . --windowed --resolution 540x600 res://src/debug/vt_row_shots.tscn -- [--vt-out=build/vt_rows]

const SCENE: String = "res://src/ui/upgrade_panel.tscn"
const SIZE: Vector2i = Vector2i(1080, 1500)


func _ready() -> void:
	var out: String = "build/vt_rows"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--vt-out="):
			out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	await _shot(out, "chassis_mk1_mk4_plated2", "chassis", {"hull_integrity": 25, "nano_repair": 0, "plating_pct": 8})
	await _shot(out, "chassis_mk2_plating_none", "chassis", {"hull_integrity": 8, "nano_repair": 12, "plating_pct": 1})
	await _shot(out, "arms_mk3_ring", "arms", {"laser_output": 24, "cycle_rate": 5})
	await _shot(out, "arms_mk4_x25", "arms", {"laser_output": 25, "cycle_rate": 5})
	get_tree().quit()


func _world(levels: Dictionary) -> SimWorld:
	var c := RunController.new()
	c.last_run_path = "user://runs/vt_row_shots.json"
	@warning_ignore("return_value_discarded")
	c.start_run(7, true)
	var w: SimWorld = c.world
	for i: int in w.config.upgrades.size():
		w.visible[i] = 1
		var id: String = w.config.upgrades[i].id
		if levels.has(id):
			w.run_levels[i] = levels[id]
	return w


func _shot(out: String, shot_name: String, tab: String, levels: Dictionary) -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var base := ColorRect.new()
	base.color = Palette.GRID
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(base)
	var panel: UpgradePanel = (load(SCENE) as PackedScene).instantiate() as UpgradePanel
	panel.max_height_px = 1300.0
	vp.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.bind(_world(levels))
	@warning_ignore("return_value_discarded")
	panel.set_tab(tab)
	for i: int in 8:
		await get_tree().process_frame
		panel.reflow()
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	if img.save_png(out.path_join("vt_%s.png" % shot_name)) != OK:
		push_error("vt shot save failed: " + shot_name)
	vp.queue_free()
	await get_tree().process_frame
