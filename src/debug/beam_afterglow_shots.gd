class_name BeamAfterglowShots
extends Node
## R1-06 desktop check: the production BattleView at 1080x2400 with the beam in its three phases, at MK I and MK III
## (laser_output level 0 and 12): the live shot, the frame between shots (core gone, afterglow and scorch left) and
## the late frame (scorch only). Saves PNGs and prints draw-call counts. Needs a window:
##   godot --path . --windowed --resolution 540x1200 res://src/debug/beam_afterglow_shots.tscn -- --out=<dir>
## Default output: docs/playtests/r1/beam.

const SIZE: Vector2i = Vector2i(1080, 2400)
const FIELD: Rect2 = Rect2(0.0, 260.0, 1080.0, 1500.0)
const T0: float = 100.0
const AIM_DEG: float = -50.0
const PHASE_NAMES: PackedStringArray = ["live", "between", "late"]
const PHASE_AGES: PackedFloat32Array = [0.03, 0.15, 0.55]
const LEVEL_TAGS: PackedStringArray = ["mk1", "mk3"]
const LEVEL_VALUES: PackedInt32Array = [0, 12]
const SPOTS: Array[Vector3] = [Vector3(-50.0, 430.0, 0), Vector3(15.0, 470.0, 1), Vector3(-130.0, 400.0, 3)]

var _out: String = ""


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://docs/playtests/r1/beam")
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	for k: int in LEVEL_TAGS.size():
		await _shots(LEVEL_TAGS[k], LEVEL_VALUES[k])
	get_tree().quit()


func _shots(tag: String, level: int) -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
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
	view.bind(c.world)
	view.set_field_rect(FIELD)
	await get_tree().process_frame
	var beams: BeamRenderer = view.get_node("Beams")
	var scorch: BeamScorch = view.get_node("Scorch")
	var enemies: EnemyRenderer = view.get_node("Enemies")
	var ends: Array[Vector2] = _place(c.world, view, enemies)
	var cinder: CinderView = view.cinder_view()
	view.band_override = 0
	for f: int in 45:
		view._aim = deg_to_rad(AIM_DEG)
		view.render(0.0)
		await get_tree().process_frame
	for p: int in PHASE_NAMES.size():
		var age: float = PHASE_AGES[p]
		for e: Vector2 in ends:
			beams.shoot(cinder.emitter_position(), e, T0, false)
		beams._now_s = T0 + age
		beams.queue_redraw()
		scorch.update(T0 + age)
		for f: int in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var calls: int = int(
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		)
		var img: Image = vp.get_texture().get_image()
		@warning_ignore("return_value_discarded")
		img.save_png(_out.path_join("%s_%s.png" % [tag, PHASE_NAMES[p]]))
		print(
			"BEAMSHOT %s %s draw_calls=%d afterglows=%d" % [tag, PHASE_NAMES[p], calls, beams.afterglow_count(T0 + age)]
		)
		beams._born.fill(-1000.0)  # next phase starts clean
		scorch._born.fill(-1000.0)
	vp.queue_free()
	await get_tree().process_frame


## Puts three enemies on fixed spots and returns the beam end points.
func _place(world: SimWorld, view: BattleView, enemies: EnemyRenderer) -> Array[Vector2]:
	var st: EnemyStore = world.enemies
	var ends: Array[Vector2] = []
	for i: int in st.high_water:
		if st.alive[i] == 0 or ends.size() >= SPOTS.size():
			continue
		var s: Vector3 = SPOTS[ends.size()]
		var ty: int = int(s.z)
		st.type_id[i] = ty
		var m: float = _meters_for(s.y, deg_to_rad(s.x), view.px_per_m(), enemies.standoff_px(ty))
		var pm: Vector2 = Vector2.from_angle(deg_to_rad(s.x)) * m
		st.pos_x[i] = pm.x
		st.pos_y[i] = pm.y
		st.prev_x[i] = pm.x
		st.prev_y[i] = pm.y
		var vr: float = enemies.sprite_radius_px(ty)
		ends.append(BeamRenderer.beam_end(pm, vr, view.px_per_m(), enemies.standoff_px(ty)))
	return ends


func _meters_for(px: float, angle: float, ppm: float, standoff: float) -> float:
	var m: float = 3.0
	while m < 60.0:
		var p: Vector2 = ViewMath.map_pos(Vector2.from_angle(angle) * m, ppm, standoff)
		if p.length() >= px:
			return m
		m += 0.1
	return m
