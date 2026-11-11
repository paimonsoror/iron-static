class_name TipShots
extends Node
## Desktop capture of the upgrade tooltips (upgrade-info pass): the PLATING and LASER OUTPUT tooltips open on the
## battle HUD, and a Foundry tooltip open. Needs a window (not --headless):
##   godot --path . --windowed --resolution 540x600 res://src/debug/tip_shots.tscn -- [--ts-out=build/tip_shots]
##   [--ts-size=1080x1920]
## Writes tip_plating.png, tip_laser.png and tip_foundry.png.

const SAFE: Vector4 = Vector4(0.0, 110.0, 0.0, 70.0)

var _out: String = "build/tip_shots"
var _size: Vector2i = Vector2i(1080, 2400)


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ts-out="):
			_out = a.get_slice("=", 1)
		elif a.begins_with("--ts-size="):
			var parts: PackedStringArray = a.get_slice("=", 1).split("x")
			if parts.size() == 2:
				_size = Vector2i(parts[0].to_int(), parts[1].to_int())
	DirAccess.make_dir_recursive_absolute(_out)
	Game.visual.set_accessibility("off", false)
	await _battle()
	await _foundry()
	get_tree().quit()


func _viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = _size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size_2d_override_stretch = false
	add_child(vp)
	return vp


func _save(vp: SubViewport, shot_name: String) -> void:
	for i: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var path: String = _out.path_join(shot_name + ".png")
	if img.save_png(path) != OK:
		push_error("tip shot save failed: " + path)
	print("[TS] %s %dx%d" % [path, img.get_width(), img.get_height()])


func _battle() -> void:
	var vp: SubViewport = _viewport()
	var cfg: SimConfig = SimConfigLoader.load_default(7)
	cfg.best_wave_s1 = 12  # unlocks PLATING
	var n: int = cfg.upgrades.size()
	cfg.foundry_levels = PackedInt32Array()
	cfg.foundry_f = PackedFloat64Array()
	for k: int in n:
		cfg.foundry_levels.append(12)
		cfg.foundry_f.append(0.1)
	var world := SimWorld.new(cfg)
	for k: int in n:
		world.run_levels[k] = 30
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(root)
	var hud: Hud = (load("res://src/ui/hud.tscn") as PackedScene).instantiate() as Hud
	root.add_child(hud)
	hud.apply_safe_margins(SAFE)
	var panel: UpgradePanel = hud.upgrade_panel()
	panel.bind(world)
	await _settle(hud, world)
	@warning_ignore("return_value_discarded")
	panel.set_tab("chassis")
	await _settle(hud, world)
	panel.row_at(_row(world, "plating_pct")).toggle_tooltip()
	await _settle(hud, world)
	await _save(vp, "tip_plating")
	panel.row_at(_row(world, "plating_pct")).toggle_tooltip()
	@warning_ignore("return_value_discarded")
	panel.set_tab("arms")
	await _settle(hud, world)
	panel.row_at(_row(world, "laser_output")).toggle_tooltip()
	await _settle(hud, world)
	await _save(vp, "tip_laser")
	vp.queue_free()
	await get_tree().process_frame


func _row(world: SimWorld, id: String) -> int:
	for i: int in world.config.upgrades.size():
		if world.config.upgrades[i].id == id:
			return i
	return 0


func _settle(hud: Hud, world: SimWorld) -> void:
	for i: int in 8:
		hud.refresh(world, 100.0 + float(i))
		hud.upgrade_panel().reflow()
		await get_tree().process_frame


func _foundry() -> void:
	var vp: SubViewport = _viewport()
	var p: PlayerProfile = PlayerProfile.fresh(0, "tips")
	p.data = BigNum.from_int(5000)
	p.runs_total = 3
	p.best_wave["1"] = 30
	p.foundry["laser_output"] = 12
	p.foundry["cycle_rate"] = 7
	@warning_ignore("return_value_discarded")
	FoundryIntroFlag.set_hidden(p, true)
	var s: FoundryScreen = (load("res://src/ui/foundry/foundry_screen.tscn") as PackedScene).instantiate()
	s.use_profile(p)
	vp.add_child(s)
	s.size = Vector2(_size)
	s.apply_safe_margins(SAFE)
	s.enter()
	for i: int in 6:
		await get_tree().process_frame
	s.row_at(0).toggle_tooltip()
	for i: int in 6:
		await get_tree().process_frame
	await _save(vp, "tip_foundry")
	vp.queue_free()
	await get_tree().process_frame
