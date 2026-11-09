class_name Vt4FxShots
extends Node
## VT-4 desktop check: the PRODUCTION deflection sparks and repair motes (FxSpawner, driven by plating_pct and
## nano_repair run levels) around the real BattleView, composed into one review sheet. Needs a window:
##   godot --path . --windowed --resolution 540x600 res://src/debug/vt4_fx_shots.tscn -- --vt4-out=<dir>
##   [--vt4-review=<file.jpg>]
## Saves one PNG per cell and the sheet (PNG in <dir>; JPG at --vt4-review when given).

const PANEL_SIZE: Vector2i = Vector2i(1080, 1440)
const CROP: int = 540
const SHEET_COLS: int = 3
const REVIEW_W: int = 1080

var _out: String = ""
var _review: String = ""


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://build/vt4")
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--vt4-out="):
			_out = a.get_slice("=", 1)
		if a.begins_with("--vt4-review="):
			_review = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	var cells: Array[Dictionary] = []
	@warning_ignore("return_value_discarded")
	await _cell("BASELINE", {}, {"hurt": true, "hits": 2})
	cells.append(await _cell("PLATED IV: DEFLECT", {"plating_pct": 30}, {"hits": 2}))
	cells.append(await _cell("PLATED II: DEFLECT", {"plating_pct": 8}, {"hits": 2}))
	cells.append(await _cell("MK II MOTES (HURT)", {"nano_repair": 5}, {"hurt": true}))
	cells.append(await _cell("MK IV MOTES (HURT)", {"nano_repair": 25}, {"hurt": true}))
	cells.append(await _cell("MK IV MOTES (FULL, 40%)", {"nano_repair": 25}, {}))
	cells.append(
		await _cell(
			"PLATED IV + MK IV, MID", {"plating_pct": 30, "nano_repair": 25}, {"hurt": true, "hits": 2, "tier": 1}
		)
	)
	cells.append(
		await _cell(
			"PLATED IV + MK IV, REDUCE",
			{"plating_pct": 30, "nano_repair": 25},
			{"hurt": true, "hits": 2, "reduce": true}
		)
	)
	cells.append(
		await _cell("PLATED IV + MK IV, HIGH", {"plating_pct": 30, "nano_repair": 25}, {"hurt": true, "hits": 2})
	)
	cells.append(
		await _cell(
			"PLATED IV + MK IV, LOW", {"plating_pct": 30, "nano_repair": 25}, {"hurt": true, "hits": 2, "tier": 2}
		)
	)
	await _sheet(cells)
	get_tree().quit()


func _visual() -> VisualSettings:
	var game: Node = get_node("/root/Game")
	var v: Variant = game.get("visual")
	var vs: VisualSettings = v
	return vs


func _cell(title: String, levels: Dictionary, o: Dictionary) -> Dictionary:
	var vis: VisualSettings = _visual()
	var reduce: bool = o.get("reduce", false)
	var qt: int = o.get("tier", 0)
	vis.reduce_motion = reduce
	vis.quality = VisualQuality.for_tier(qt as VisualQuality.Tier)
	var vp := SubViewport.new()
	vp.size = PANEL_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var c := RunController.new()
	c.start_run(7, true)
	var w: SimWorld = c.world
	for i: int in w.config.upgrades.size():
		var id: String = w.config.upgrades[i].id
		if levels.has(id):
			w.run_levels[i] = levels[id]
	var hurt: bool = o.get("hurt", false)
	if hurt:
		w.cinder.hp = w.cinder.max_hp * 0.6
	var view: BattleView = (load("res://src/view/battle_view.tscn") as PackedScene).instantiate()
	vp.add_child(view)
	view.bind(w)
	await get_tree().process_frame
	await get_tree().process_frame
	for f: int in 60:
		w.tick += 1
		view.render(0.0)
		await get_tree().process_frame
	var hits: int = o.get("hits", 0)
	for h: int in hits:
		w.events.push(SimEventKind.CINDER_HIT, 10, 0)
	if hits > 0:
		w.tick += 1
		for k: int in 2:
			w.tick += 1
			view.render(0.0)
		view.render(0.0)
	for f: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var calls: int = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	print("DRAWCALLS ", title, " ", calls)
	var img: Image = vp.get_texture().get_image()
	var center: Vector2i = Vector2i(view.position)
	vp.queue_free()
	await get_tree().process_frame
	var crop: Image = img.get_region(
		Rect2i(center.x - floori(float(CROP) / 2.0), center.y - floori(float(CROP) / 2.0), CROP, CROP)
	)
	crop.save_png(_out.path_join("vt4_%s.png" % title.to_lower().replace(" ", "_").replace(":", "").replace(",", "")))
	return {"img": crop, "title": title}


func _sheet(cells: Array[Dictionary]) -> void:
	var rows: int = ceili(float(cells.size()) / float(SHEET_COLS))
	var vp := SubViewport.new()
	vp.size = Vector2i(CROP * SHEET_COLS, (CROP + 40) * rows)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var bg := ColorRect.new()
	bg.color = Palette.VOID
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	for i: int in cells.size():
		var x: int = (i % SHEET_COLS) * CROP
		var y: int = floori(float(i) / float(SHEET_COLS)) * (CROP + 40)
		var im: Image = cells[i]["img"]
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(im)
		tr.position = Vector2(x, y)
		vp.add_child(tr)
		var l := Label.new()
		l.text = str(cells[i]["title"])
		l.add_theme_font_size_override("font_size", 24)
		l.add_theme_color_override("font_color", Palette.AMBER_GLOW)
		l.position = Vector2(x + 12, y + CROP + 4)
		vp.add_child(l)
	for f: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.save_png(_out.path_join("vt4_sheet.png"))
	if _review != "":
		var j: Image = img.duplicate()
		j.convert(Image.FORMAT_RGB8)
		j.resize(
			REVIEW_W, roundi(float(j.get_height()) * float(REVIEW_W) / float(j.get_width())), Image.INTERPOLATE_LANCZOS
		)
		j.save_jpg(_review, 0.86)
	vp.queue_free()
