class_name IntelShots
extends Node
## Desktop capture harness of the Intel Wave panel (M4-19). Hosts the production `UpgradePanel` on the INTEL tab over
## a plain backdrop mid-run (TIMED wave 8, PURGE wave 8, wide layout) and saves PNGs, then quits:
##   godot --path . --windowed --resolution 540x600 res://src/debug/intel_shots.tscn -- [--is-out=build/m4_intelwave]

const SCENE: String = "res://src/ui/upgrade_panel.tscn"
const PORTRAIT: Vector2i = Vector2i(1080, 2400)
const WIDE: Vector2i = Vector2i(1990, 1920)


func _ready() -> void:
	var out: String = "build/m4_intelwave"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--is-out="):
			out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	await _shot(out, "wave_timed", PORTRAIT, false, "timed", "wave")
	await _shot(out, "wave_purge", PORTRAIT, false, "purge", "wave")
	await _shot(out, "stats", PORTRAIT, false, "timed", "stats")
	await _shot(out, "wave_wide", WIDE, true, "timed", "wave")
	get_tree().quit()


func _world(mode: String) -> SimWorld:
	var c := RunController.new()
	c.last_run_path = "user://runs/intel_shots.json"
	@warning_ignore("return_value_discarded")
	c.start_run(7, true)
	c.world.config.wave_mode = mode
	@warning_ignore("return_value_discarded")
	c.fast_forward(7 * Ticks.WAVE_TICKS + 200)
	return c.world


func _shot(out: String, shot_name: String, size: Vector2i, wide: bool, mode: String, sub: String) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var base := ColorRect.new()
	base.color = Palette.GRID
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(base)
	var panel: UpgradePanel = (load(SCENE) as PackedScene).instantiate() as UpgradePanel
	panel.wide = wide
	panel.max_height_px = 1500.0
	vp.add_child(panel)
	if wide:
		panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
		panel.offset_left = -900.0
	else:
		panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.bind(_world(mode))
	@warning_ignore("return_value_discarded")
	panel.set_tab("intel")
	@warning_ignore("return_value_discarded")
	panel.intel_hub().set_sub(sub)
	panel.intel_hub().wave_panel().refresh()
	panel.intel_hub().stats_panel().refresh()
	for i: int in 8:
		await get_tree().process_frame
		panel.reflow()
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	if img.save_png(out.path_join("intel_%s.png" % shot_name)) != OK:
		push_error("intel shot save failed: " + shot_name)
	vp.queue_free()
	await get_tree().process_frame
