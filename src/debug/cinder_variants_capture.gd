class_name CinderVariantsCapture
extends Node
## M3-27 desktop capture series of the Cinder frame variants (`-- --cvc-shots=<dir>`): for each frame the rig at
## bands 0-3 (real BattleView bound to a real SimWorld whose config carries the frame id, so the selection hook is
## exercised) and a crowd shot. Renders into a 1080x2400 SubViewport, saves PNGs, prints [CVC] metric lines, quits.

const SIZE: Vector2i = Vector2i(1080, 2400)
const FRAMES: Array[String] = ["vanguard", "bulwark", "striker"]
const CROP: int = 360

var _vp: SubViewport = null
var _only: String = ""


func _ready() -> void:
	var out: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--cvc-shots"):
			out = a.get_slice("=", 1) if "=" in a else "build/cvc"
		elif a.begins_with("--cvc-only="):
			_only = a.get_slice("=", 1)
	if out.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(out)
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_run(out)


func _run(out: String) -> void:
	for fid: String in FRAMES:
		if not _only.is_empty() and fid != _only:
			continue
		var world := SimWorld.new(SimConfigLoader.load_default(7))
		world.config.frame_id = fid
		var scene: PackedScene = load("res://src/view/battle_view.tscn")
		var view: BattleView = scene.instantiate()
		_vp.add_child(view)
		view.layout(Vector2(SIZE))
		view.bind(world)
		var cinder: CinderView = view.cinder_view()
		print(
			(
				"[CVC] %s frame_id=%s emitter0=%s radius_px=%.1f"
				% [fid, _frame_of(cinder), cinder.emitter_node_position(0), cinder.radius_px]
			)
		)
		if fid == FRAMES[0] or not _only.is_empty():
			cinder.visible = false
			await _settle(view, world, 20)
			await _save_crop(view, out, "M3-27_background.png")
			cinder.visible = true
		for band: int in 4:
			view.band_override = band
			await _settle(view, world, 60)
			await _save_crop(view, out, "M3-27_%s_b%d.png" % [fid, band])
		view.band_override = 0
		for i: int in 2400:
			world.step()
			if i % 4 == 0 and world.cinder.hp < world.cinder.max_hp * 0.5:
				world.cinder.hp = world.cinder.max_hp
		_add_crowd(world, 90)
		print("[CVC] %s crowd alive=%d" % [fid, world.enemies.alive_count])
		await _settle(view, world, 20)
		await RenderingServer.frame_post_draw
		_vp.get_texture().get_image().get_region(Rect2i(0, 0, SIZE.x, 1344)).save_png(
			out.path_join("M3-27_%s_crowd.png" % fid)
		)
		view.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _settle(view: BattleView, world: SimWorld, frames: int) -> void:
	for i: int in frames:
		world.step()
		view.render(0.5)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save_crop(view: BattleView, out: String, file: String) -> void:
	var img: Image = _vp.get_texture().get_image()
	var c: Vector2 = view.position
	var r := Rect2i(int(c.x) - (CROP >> 1), int(c.y) - (CROP >> 1), CROP, CROP)
	var crop: Image = img.get_region(r)
	crop.save_png(out.path_join(file))


## Fills the arena with a deterministic mixed crowd (hp huge, speed 0) so the capture shows Cinder among enemies.
func _add_crowd(world: SimWorld, count: int) -> void:
	var st: EnemyStore = world.enemies
	for n: int in count:
		var idx: int = st.alloc(n % 4)
		if idx < 0:
			return
		var ang: float = float(n) * 2.399963
		var dist: float = 5.0 + 17.0 * sqrt(float(n) / float(count))
		st.pos_x[idx] = cos(ang) * dist
		st.pos_y[idx] = sin(ang) * dist
		st.prev_x[idx] = st.pos_x[idx]
		st.prev_y[idx] = st.pos_y[idx]
		st.radius[idx] = 0.8 if n % 4 != 2 else 1.4
		st.speed[idx] = 0.0
		st.hp[idx] = 1e12
		st.max_hp[idx] = 1e12


## `frame_id()` through `call` so the same script also runs against the pre-M3-27 view (parity capture).
func _frame_of(cinder: CinderView) -> String:
	if cinder.has_method("frame_id"):
		var got: Variant = cinder.call("frame_id")
		return str(got)
	return "(pre-M3-27)"
