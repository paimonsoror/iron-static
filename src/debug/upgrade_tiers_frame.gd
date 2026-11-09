class_name UpgradeTiersFrame
extends Node
## Style-frame harness of the upgrade visual tiers (docs/design/12_upgrade_visual_tiers.md). Desktop only, needs a
## window. Renders the REAL BattleView (arena, Cinder rig, enemies, particle ring) in a SubViewport and adds the
## mockup layers (tiered beam `UtBeam`, plate cells `UtPlates`, tier-up flash `UtFlash`, banner and rows as Controls),
## then saves PNG panels and review sheets, and quits:
##   godot --path . --windowed --resolution 540x600 res://src/debug/upgrade_tiers_frame.tscn -- --ut-out=<dir>
##   [--ut-review=<dir>]  (default: docs/design/style/upgrade_tiers, committed JPG sheets)
## Mockup only: it reads nothing but the proposed tier table and never touches production behaviour.

const PANEL_SIZE: Vector2i = Vector2i(1080, 1440)
const CROP: int = 540
const SHEET_W: int = 1200
const REVIEW_W: int = 1080
const AIM_DEG: float = -50.0
const TARGET_PX: float = 215.0
const STILL_T: float = 100.0
## Mockup plates are drawn a bit larger than the integrity ring so the silhouette grows with the tier.
const PLATE_SCALE: float = 1.14

var _tiers: UtTiers = UtTiers.load_default()
var _ui: UtUi = UtUi.new()
var _out: String = ""
var _review: String = ""


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://build/ut_frame")
	_review = ProjectSettings.globalize_path("res://docs/design/style/upgrade_tiers")
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ut-out="):
			_out = a.get_slice("=", 1)
		if a.begins_with("--ut-review="):
			_review = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	DirAccess.make_dir_recursive_absolute(_review)
	await _beam_sheet()
	await _armor_sheet()
	await _fx_sheet()
	await _tier_up_frame()
	get_tree().quit()


# ---------------------------------------------------------------- sheets


func _beam_sheet() -> void:
	var cells: Array[Dictionary] = []
	for t: int in range(1, 5):
		var img: Image = await _panel({"laser": t, "aim": true})
		cells.append({"img": img, "title": "LASER %s" % _tiers.mark("laser_output", t), "sub": _sub("laser_output", t)})
	await _save_sheet("ut_beam_tiers", cells)


func _armor_sheet() -> void:
	var cells: Array[Dictionary] = []
	for p: int in 4:
		var img: Image = await _panel({"plates": p, "laser": 1, "aim": false})
		var mk: String = _tiers.mark("hull_integrity", p + 1)
		cells.append({"img": img, "title": "HULL %s" % mk, "sub": _sub("hull_integrity", p + 1)})
	await _save_sheet("ut_armor_tiers", cells)


func _fx_sheet() -> void:
	var cells: Array[Dictionary] = []
	var d: Image = await _panel({"plates": 2, "laser": 1, "deflect": 3, "aim": false})
	cells.append({"img": d, "title": "PLATING: DEFLECTION SPARKS", "sub": "teal-white ricochet at the plate edge"})
	var lo: Image = await _panel({"plates": 1, "laser": 1, "motes": 5, "aim": false})
	cells.append({"img": lo, "title": "REPAIR MK II: 5 MOTES", "sub": _sub("nano_repair", 2)})
	var hi: Image = await _panel({"plates": 1, "laser": 1, "motes": 16, "aim": false})
	cells.append({"img": hi, "title": "REPAIR MK IV: 16 MOTES", "sub": _sub("nano_repair", 4)})
	var burn: Image = await _panel({"plates": 3, "laser": 1, "motes": 8, "band": 2, "aim": false})
	cells.append({"img": burn, "title": "HULL MK IV + SKIN BURN BAND 2", "sub": "plates stay, wedges char underneath"})
	await _save_sheet("ut_armor_fx", cells)


func _sub(upgrade: String, tier: int) -> String:
	for r: Dictionary in _tiers.rows:
		if r["upgrade"] == upgrade and r["tier"] == tier:
			if r["kind"] == "level":
				return "from level %d" % _oi(r, "threshold", 0)
			return "from %d%% of cap" % roundi(_of(r, "threshold", 0.0) * 100.0)
	return ""


func _tier_up_frame() -> void:
	var img: Image = await _panel({"laser": 2, "plates": 1, "motes": 5, "aim": true, "full": true, "flash_t": 0.14})
	img.save_png(_out.path_join("ut_tier_up.png"))
	var j: Image = img.duplicate()
	j.convert(Image.FORMAT_RGB8)
	j.save_jpg(_review.path_join("ut_tier_up.jpg"), 0.88)


# ---------------------------------------------------------------- panel


## Builds one battle frame and returns the 600 px crop around Cinder (or the whole frame with `full`).
func _panel(o: Dictionary) -> Image:
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
	var view: BattleView = (load("res://src/view/battle_view.tscn") as PackedScene).instantiate()
	vp.add_child(view)
	view.bind(c.world)
	await get_tree().process_frame
	await get_tree().process_frame
	var enemies: EnemyRenderer = view.get_node("Enemies")
	var spots: Array[Vector3] = [Vector3(AIM_DEG, TARGET_PX, 0), Vector3(20.0, 250.0, 1), Vector3(-140.0, 235.0, 3)]
	var st: EnemyStore = c.world.enemies
	var idx: int = 0
	var target_end: Vector2 = Vector2.ZERO

	var aim: float = deg_to_rad(AIM_DEG)
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
	var plates: UtPlates = UtPlates.new()
	plates.count = _oi(o, "plates", 0)
	plates.px_per_texel = 0.5 * CinderLayout.rig_scale(cinder.radius_px) * PLATE_SCALE
	view.add_child(plates)
	view.move_child(plates, cinder.get_index())
	var pg := UtPlates.Glow.new()
	pg.plates = plates
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pg.material = mat
	view.add_child(pg)
	view.move_child(pg, cinder.get_index())
	var beams: BeamRenderer = view.get_node("Beams")
	var beam: UtBeam = null
	if _ob(o, "aim"):
		beams.visible = false
		beam = UtBeam.new()
		beam.px_scale = view.sprite_factor()
		beam.tier_params = _tiers.params("laser_output", _oi(o, "laser", 1))
		beam.ripple_phase = 0.3
		view.add_child(beam)
		view.move_child(beam, beams.get_index())
	else:
		beams.visible = false
	view.band_override = _oi(o, "band", 0)
	for f: int in 45:
		view._aim = aim
		view.render(0.0)
		await get_tree().process_frame
	if beam != null:
		beam.shoot(cinder.emitter_position(), target_end, STILL_T, false)
		beam._now_s = STILL_T
		beam.queue_redraw()
	_particles(view, cinder, o, aim)
	var flash: UtFlash = null
	if o.has("flash_t"):
		flash = UtFlash.new()
		flash.t = _of(o, "flash_t", 0.0)
		flash.radius_px = cinder.radius_px
		var fm := CanvasItemMaterial.new()
		fm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		flash.material = fm
		view.add_child(flash)
	if _ob(o, "full"):
		_ui.overlay(vp, view)
	for f: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var center: Vector2i = Vector2i(view.position)
	vp.queue_free()
	await get_tree().process_frame
	if _ob(o, "full"):
		return img
	return img.get_region(
		Rect2i(center.x - floori(float(CROP) / 2.0), center.y - floori(float(CROP) / 2.0), CROP, CROP)
	)


## Sim meters along `angle` whose mapped distance is `px`.
func _meters_for(px: float, angle: float, ppm: float, standoff: float) -> float:
	var m: float = 3.0
	while m < 60.0:
		var p: Vector2 = ViewMath.map_pos(Vector2.from_angle(angle) * m, ppm, standoff)
		if p.length() >= px:
			return m
		m += 0.1
	return m


# ---------------------------------------------------------------- particles


func _particles(view: BattleView, cinder: CinderView, o: Dictionary, aim: float) -> void:
	var em: FxEmitter = view.fx().emitter
	var pool: ParticlePool = em.additive
	var now: float = em.now
	var r: float = cinder.radius_px
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var defl: int = _oi(o, "deflect", 0)
	if defl > 0:
		var p: Dictionary = _tiers.params("plating_pct", defl)
		var sc: float = _of(p, "spark_scale", 1.0)
		var angles: Array[float] = [aim, deg_to_rad(14.0), deg_to_rad(-135.0), deg_to_rad(95.0)]
		for a: float in angles:
			_deflect(pool, now, Vector2.from_angle(a) * r * 1.22, a, sc, rng)
	var motes: int = _oi(o, "motes", 0)
	if motes > 0:
		var mp: Dictionary = _tiers.params("nano_repair", 2 if motes < 8 else (3 if motes < 12 else 4))
		var sp: float = _of(mp, "speed", 70.0)
		var sz: float = _of(mp, "size", 8.0)
		for k: int in motes:
			var th: float = rng.randf() * TAU
			var rr: float = r * rng.randf_range(1.02, 1.32)
			var age: float = rng.randf_range(0.0, 0.95)
			var tan: Vector2 = Vector2.from_angle(th + PI * 0.5)
			var v: Vector2 = tan * sp * rng.randf_range(0.75, 1.1) + Vector2.from_angle(th) * 14.0
			var col: Color = Palette.TEAL.lerp(Color.WHITE, rng.randf_range(0.1, 0.45))
			var fade: float = 1.0 - age / 1.3
			col.a = 0.95 * fade
			var pos: Vector2 = Vector2.from_angle(th) * rr
			pool.emit(pos, v, now - age, 1.3, Vector2(sz, sz * 0.6), col, ParticlePack.KIND_EMBER_A)
			var halo: Color = Palette.TEAL
			halo.a = 0.55 * fade
			pool.emit(pos, v, now - age, 1.3, Vector2(sz * 3.2, sz * 2.0), halo, ParticlePack.KIND_HALO)
	view.get_node("Particles").call("flush")


func _deflect(pool: ParticlePool, now: float, pos: Vector2, ang: float, sc: float, rng: RandomNumberGenerator) -> void:
	var age: float = 0.07
	var white := Color(0.85, 1.0, 0.98, 1.0)
	pool.emit(pos, Vector2.ZERO, now - age, 0.1, Vector2(26.0, 34.0) * sc, white, ParticlePack.KIND_FLASH)
	pool.emit(
		pos,
		Vector2.ZERO,
		now - age,
		0.2,
		Vector2(30.0, 64.0) * sc,
		Color(Palette.TEAL, 0.8),
		ParticlePack.KIND_RING_THIN
	)
	pool.emit(
		pos, Vector2.ZERO, now - age, 0.2, Vector2(46.0, 60.0) * sc, Color(Palette.TEAL, 0.3), ParticlePack.KIND_HALO
	)
	pool.emit(pos, Vector2.ZERO, now - age, 0.16, Vector2(46.0, 56.0) * sc, white, ParticlePack.KIND_FLARE4)
	for k: int in roundi(6.0 * sc):
		var side: float = -1.0 if k % 2 == 0 else 1.0
		var a: float = ang + side * rng.randf_range(0.55, 1.0)
		var v: Vector2 = Vector2.from_angle(a) * rng.randf_range(300.0, 470.0)
		var len_px: float = rng.randf_range(44.0, 78.0) * sc
		var col: Color = Palette.TEAL.lerp(Color.WHITE, rng.randf_range(0.35, 0.9))
		col.a = 0.95
		var kind: int = ParticlePack.KIND_SPARK_A + rng.randi_range(0, 2)
		pool.emit(pos, v, now - age - rng.randf_range(0.0, 0.05), 0.24, Vector2(len_px, len_px * 0.3), col, kind)


# ---------------------------------------------------------------- sheet compose


func _save_sheet(sheet_name: String, cells: Array[Dictionary]) -> void:
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
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(_img(d))
		tr.position = Vector2(x + 4, y + 4)
		tr.size = Vector2(cw - 8, cw - 8)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		vp.add_child(tr)
		var t: Label = _ui.label(str(d["title"]), 30, Palette.AMBER_GLOW, ox)
		t.position = Vector2(x + 16, y + cw - 2)
		vp.add_child(t)
		var s: Label = _ui.label(str(d["sub"]), 22, Palette.TEXT_DIM, mono)
		s.position = Vector2(x + 16, y + cw + 36)
		vp.add_child(s)
		vp.add_child(_ui.rect(Vector2(x + 2, y + 2), Vector2(cw - 4, 2), Palette.AMBER_DIM))
	for f: int in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.save_png(_out.path_join(sheet_name + ".png"))
	var j: Image = img.duplicate()
	j.convert(Image.FORMAT_RGB8)
	j.resize(
		REVIEW_W, roundi(float(j.get_height()) * float(REVIEW_W) / float(j.get_width())), Image.INTERPOLATE_LANCZOS
	)
	j.save_jpg(_review.path_join(sheet_name + ".jpg"), 0.86)
	vp.queue_free()
	await get_tree().process_frame


func _oi(d: Dictionary, key: String, fallback: int) -> int:
	var v: Variant = d.get(key, fallback)
	if v is int or v is float or v is bool:
		var n: int = v
		return n
	return fallback


func _of(d: Dictionary, key: String, fallback: float) -> float:
	var v: Variant = d.get(key, fallback)
	if v is int or v is float:
		var n: float = v
		return n
	return fallback


func _ob(d: Dictionary, key: String) -> bool:
	var v: Variant = d.get(key, false)
	return v is bool and v


func _img(d: Dictionary) -> Image:
	var im: Image = d["img"]
	return im
