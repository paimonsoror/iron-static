class_name Vt2BeamFrame
extends Node
## VT-2 desktop check: renders the PRODUCTION BattleView (real BeamRenderer driven by the run's laser_output level)
## at MK I to IV, a crit and the quality variants, prints RenderingServer draw-call counts and saves PNGs plus one
## review sheet. Needs a window:
##   godot --path . --windowed --resolution 540x600 res://src/debug/vt2_beam_frame.tscn -- --vt2-out=<dir>
##   [--vt2-review=<jpg>]
## Defaults: build/vt2 and docs/design/style/upgrade_tiers/vt2_beam_production.jpg.

const PANEL_SIZE: Vector2i = Vector2i(1080, 1440)
const CROP: int = 540
const REVIEW_W: int = 1080
const AIM_DEG: float = -50.0
const TARGET_PX: float = 215.0
const STILL_T: float = 100.0
const LEVELS: Array[int] = [0, 5, 12, 25]

var _out: String = ""
var _review: String = ""


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://build/vt2")
	_review = ProjectSettings.globalize_path("res://docs/design/style/upgrade_tiers/vt2_beam_production.jpg")
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--vt2-out="):
			_out = a.get_slice("=", 1)
		if a.begins_with("--vt2-review="):
			_review = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	var tiers: Array[Image] = []
	for t: int in 4:
		var r: Dictionary = await _panel(LEVELS[t], false, VisualQuality.Tier.HIGH, false, 1)
		var img: Image = r["img"]
		img.save_png(_out.path_join("mk%d.png" % (t + 1)))
		tiers.append(img)
		print("VT2 draw_calls mk%d: total=%d beams_hidden=%d" % [t + 1, r["calls"], r["calls_off"]])
	var crit: Dictionary = await _panel(25, true, VisualQuality.Tier.HIGH, false, 1)
	var cimg: Image = crit["img"]
	cimg.save_png(_out.path_join("mk4_crit.png"))
	var many: Dictionary = await _panel(25, false, VisualQuality.Tier.HIGH, false, 16)
	print("VT2 draw_calls mk4 x16 beams: total=%d beams_hidden=%d" % [many["calls"], many["calls_off"]])
	var many1: Dictionary = await _panel(0, false, VisualQuality.Tier.HIGH, false, 16)
	print("VT2 draw_calls mk1 x16 beams: total=%d beams_hidden=%d" % [many1["calls"], many1["calls_off"]])
	var variants: Array[Image] = []
	for v: Array in [[VisualQuality.Tier.MID, false], [VisualQuality.Tier.LOW, false], [VisualQuality.Tier.HIGH, true]]:
		var tier: VisualQuality.Tier = v[0]
		var calm: bool = v[1]
		var vr: Dictionary = await _panel(25, false, tier, calm, 1)
		var vimg: Image = vr["img"]
		variants.append(vimg)
	variants.append(cimg)
	_sheet(tiers, _review)
	_sheet(variants, _out.path_join("variants.jpg"))
	get_tree().quit()


func _panel(level: int, crit: bool, tier: VisualQuality.Tier, calm: bool, count: int) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = PANEL_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var c := RunController.new()
	c.start_run(7, true)
	var guard: int = 0
	while c.world.enemies.alive_count < 3 and guard < 6000:
		c.fast_forward(5)
		guard += 5
	for i: int in c.world.config.upgrades.size():
		if c.world.config.upgrades[i].id == "laser_output":
			c.world.run_levels[i] = level
	var view: BattleView = (load("res://src/view/battle_view.tscn") as PackedScene).instantiate()
	vp.add_child(view)
	var beams: BeamRenderer = view.get_node("Beams")
	var vs := VisualSettings.new()
	vs.set_tier(tier)
	vs.reduce_motion = calm
	beams.visual = vs
	view.bind(c.world)
	await get_tree().process_frame
	await get_tree().process_frame
	var enemies: EnemyRenderer = view.get_node("Enemies")
	var spots: Array[Vector3] = [Vector3(AIM_DEG, TARGET_PX, 0), Vector3(20.0, 250.0, 1), Vector3(-140.0, 235.0, 3)]
	var st: EnemyStore = c.world.enemies
	var idx: int = 0
	var target_end: Vector2 = Vector2.ZERO
	for i: int in st.high_water:
		if st.alive[i] == 0 or idx >= spots.size():
			continue
		var s: Vector3 = spots[idx]
		var ty: int = int(s.z)
		st.type_id[i] = ty
		var m: float = _meters_for(s.y, deg_to_rad(s.x), view.px_per_m(), enemies.standoff_px(ty))
		var pm: Vector2 = Vector2.from_angle(deg_to_rad(s.x)) * m
		st.pos_x[i] = pm.x
		st.pos_y[i] = pm.y
		st.prev_x[i] = pm.x
		st.prev_y[i] = pm.y
		if idx == 0:
			var vr: float = enemies.sprite_radius_px(ty)
			target_end = BeamRenderer.beam_end(pm, vr, view.px_per_m(), enemies.standoff_px(ty))
		idx += 1
	var cinder: CinderView = view.cinder_view()
	view.band_override = 0
	for f: int in 45:
		view._aim = deg_to_rad(AIM_DEG)
		view.render(0.0)
		await get_tree().process_frame
	for k: int in count:
		beams.shoot(cinder.emitter_position(), target_end, STILL_T, crit)
	beams._now_s = STILL_T
	beams.queue_redraw()
	for f: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var calls: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	var img: Image = vp.get_texture().get_image()
	var center: Vector2i = Vector2i(view.position)
	beams.visible = false
	for f: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var calls_off: int = int(
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	)
	vp.queue_free()
	await get_tree().process_frame
	var crop: Image = img.get_region(
		Rect2i(center.x - floori(float(CROP) / 2.0), center.y - floori(float(CROP) / 2.0), CROP, CROP)
	)
	return {"img": crop, "calls": calls, "calls_off": calls_off}


func _sheet(imgs: Array, path: String) -> void:
	var sheet := Image.create(CROP * 2, CROP * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Palette.VOID)
	for i: int in imgs.size():
		var im: Image = imgs[i]
		sheet.blit_rect(im, Rect2i(0, 0, CROP, CROP), Vector2i((i % 2) * CROP, floori(float(i) / 2.0) * CROP))
	var j: Image = sheet.duplicate()
	j.convert(Image.FORMAT_RGB8)
	if j.get_width() != REVIEW_W:
		j.resize(REVIEW_W, REVIEW_W, Image.INTERPOLATE_LANCZOS)
	j.save_jpg(path, 0.88)


## Sim meters along `angle` whose mapped distance is `px`.
func _meters_for(px: float, angle: float, ppm: float, standoff: float) -> float:
	var m: float = 3.0
	while m < 60.0:
		var p: Vector2 = ViewMath.map_pos(Vector2.from_angle(angle) * m, ppm, standoff)
		if p.length() >= px:
			return m
		m += 0.1
	return m
