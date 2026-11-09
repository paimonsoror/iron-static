class_name Vt3PlatesFrame
extends Node
## Desktop capture harness of the VT-3 production armor plates. Renders the REAL BattleView (arena, Cinder rig,
## production plates picked from the hull_integrity run level) in SubViewports and composes a review sheet. Needs a
## window:
##   godot --path . --windowed --resolution 540x600 res://src/debug/vt3_plates_frame.tscn -- [--vt3-out=build/vt3]
##   [--vt3-review=<dir>]  (default: docs/design/style/upgrade_tiers, committed JPG)
## Panels: hull MK I to IV, MK IV with skin burn band 2, MK IV on LOW quality, MK IV on the bulwark and striker frames.

const PANEL_SIZE: Vector2i = Vector2i(1080, 1440)
const CROP: int = 540
const SHEET_W: int = 1080
const AIM_DEG: float = -50.0
const PHONE_CROP: int = 256

var _ui: UtUi = UtUi.new()
var _out: String = "build/vt3"
var _review: String = ""


func _ready() -> void:
	_review = ProjectSettings.globalize_path("res://docs/design/style/upgrade_tiers")
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--vt3-out="):
			_out = a.get_slice("=", 1)
		if a.begins_with("--vt3-review="):
			_review = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	var cells: Array[Dictionary] = []
	var levels: Array[int] = [0, 5, 12, 25]
	var marks: Array[String] = ["I", "II", "III", "IV"]
	for i: int in 4:
		cells.append(await _cell("HULL MK %s" % marks[i], "hull level %d" % levels[i], {"level": levels[i]}))
	cells.append(await _cell("MK IV + SKIN BURN BAND 2", "plates stay, wedges char", {"level": 25, "band": 2}))
	cells.append(await _cell("MK IV, LOW QUALITY", "no glow twin, body plates unchanged", {"level": 25, "low": true}))
	cells.append(await _cell("MK IV, BULWARK FRAME", "shared plate cells", {"level": 25, "frame": "bulwark"}))
	cells.append(await _cell("MK IV, STRIKER FRAME", "shared plate cells", {"level": 25, "frame": "striker"}))
	await _save_sheet(cells)
	get_tree().quit()


func _cell(title: String, sub: String, o: Dictionary) -> Dictionary:
	var img: Image = await _panel(o)
	return {"img": img, "title": title, "sub": sub}


func _panel(o: Dictionary) -> Image:
	var vp := SubViewport.new()
	vp.size = PANEL_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var c := RunController.new()
	c.last_run_path = "user://runs/vt3_plates_frame.json"
	@warning_ignore("return_value_discarded")
	c.start_run(7, true)
	var guard: int = 0
	while c.world.enemies.alive_count < 3 and guard < 6000:
		c.fast_forward(5)
		guard += 5
	var lvl: int = _oi(o, "level")
	for i: int in c.world.config.upgrades.size():
		if c.world.config.upgrades[i].id == CinderPlates.UPGRADE_ID:
			c.world.run_levels[i] = lvl
	var view: BattleView = (load("res://src/view/battle_view.tscn") as PackedScene).instantiate()
	vp.add_child(view)
	view.bind(c.world)
	var cinder: CinderView = view.cinder_view()
	if o.has("frame"):
		cinder.set_frame(str(o["frame"]))
	if o.has("low"):
		var vs := VisualSettings.new()
		vs.quality = VisualQuality.low()
		cinder.visual = vs
	view.band_override = _oi(o, "band")
	var aim: float = deg_to_rad(AIM_DEG)
	for f: int in 45:
		view._aim = aim
		view.render(0.0)
		await get_tree().process_frame
	(view.get_node("Beams") as Node2D).visible = false
	for f: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var center: Vector2i = Vector2i(view.position)
	vp.queue_free()
	await get_tree().process_frame
	return img.get_region(
		Rect2i(center.x - floori(float(CROP) / 2.0), center.y - floori(float(CROP) / 2.0), CROP, CROP)
	)


func _save_sheet(cells: Array[Dictionary]) -> void:
	var cw: int = floori(float(SHEET_W) / 2.0)
	var ch: int = cw + 74
	var rows: int = ceili(float(cells.size()) / 2.0)
	var vp := SubViewport.new()
	vp.size = Vector2i(SHEET_W, ch * rows)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = Palette.VOID
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var ox: Font = _ui.make_font(UtUi.OXANIUM, 4)
	var mono: Font = _ui.make_font(UtUi.MONO, 1)
	for i: int in cells.size():
		var x: int = (i % 2) * cw
		var y: int = floori(float(i) / 2.0) * ch
		var d: Dictionary = cells[i]
		var im: Image = d["img"]
		im.save_png(_out.path_join("panel_%d.png" % i))
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(im)
		tr.position = Vector2(x + 2, y + 2)
		tr.size = Vector2(cw - 4, cw - 4)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		vp.add_child(tr)
		vp.add_child(_ui.label(str(d["title"]), 30, Palette.AMBER_GLOW, ox))
		var t: Label = vp.get_child(vp.get_child_count() - 1)
		t.position = Vector2(x + 16, y + cw - 2)
		var s: Label = _ui.label(str(d["sub"]), 22, Palette.TEXT_DIM, mono)
		s.position = Vector2(x + 16, y + cw + 36)
		vp.add_child(s)
	for f: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.save_png(_out.path_join("vt3_plates_production.png"))
	var j: Image = img.duplicate()
	j.convert(Image.FORMAT_RGB8)
	j.save_jpg(_review.path_join("vt3_plates_production.jpg"), 0.86)
	vp.queue_free()
	await get_tree().process_frame


func _oi(d: Dictionary, key: String) -> int:
	var v: Variant = d.get(key, 0)
	if v is int:
		var n: int = v
		return n
	return 0
