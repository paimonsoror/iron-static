class_name DmgnumShots
extends Node
## Desktop capture of the damage numbers (M4-21): a real BattleView in a 1080x2400 SubViewport, a bot-played run
## stepped in near real time, PNGs of the busiest frames plus draw-call counts with and without the layer:
##   godot --path . --windowed --resolution 540x600 res://src/debug/dmgnum_shots.tscn -- [--dn-out=build/m4_dmgnum]
##   [--dn-reduce] [--quality=low]

const SIZE: Vector2i = Vector2i(1080, 2400)

var _vp: SubViewport = null


func _ready() -> void:
	var out: String = "build/m4_dmgnum"
	var reduce: bool = false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--dn-out="):
			out = a.get_slice("=", 1)
		elif a == "--dn-reduce":
			reduce = true
	DirAccess.make_dir_recursive_absolute(out)
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	await _run(out, reduce)
	get_tree().quit()


func _run(out: String, reduce: bool) -> void:
	var world := SimWorld.new(SimConfigLoader.load_default(7))
	var view: BattleView = (load("res://src/view/battle_view.tscn") as PackedScene).instantiate()
	_vp.add_child(view)
	var settings := VisualSettings.new()
	settings.reduce_motion = reduce
	view.get_node("DamageNumbers").set("visual", settings)
	view.layout(Vector2(SIZE))
	view.bind(world)
	var bot := PolicyBot.new("all")
	var layer: DamageNumberLayer = view.get_node("DamageNumbers")
	var best: int = 0
	var shots: int = 0
	var calls_on: int = 0
	var calls_off: int = 0
	var suffix: String = "_reduce" if reduce else ""
	for frame: int in 5000:
		if world.tick % 15 == 0:
			bot.think(world)
		PolicyBot.settle_draft(world)
		if not world.is_over():
			world.step()
			world.step()
		view.render(1.0)
		await RenderingServer.frame_post_draw
		var live: int = layer.model.live_count()
		if frame > 120 and live > best and shots < 6:
			best = live
			if live >= 4 and frame % 5 == 0:
				_save(out, "numbers%s_%d.png" % [suffix, shots])
				shots += 1
				await RenderingServer.frame_post_draw
				calls_on = _calls()
				layer.visible = false
				await RenderingServer.frame_post_draw
				await RenderingServer.frame_post_draw
				calls_off = _calls()
				layer.visible = true
				print(
					(
						"[DN] frame=%d live=%d wave=%d calls_on=%d calls_off=%d"
						% [frame, live, world.wave, calls_on, calls_off]
					)
				)
		if shots >= 6:
			break
	print(
		(
			"[DN] done shown=%d dropped=%d lost=%d"
			% [layer.model.shown_total, layer.model.dropped_total, view.events_lost_total()]
		)
	)


func _calls() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func _save(out: String, name: String) -> void:
	var img: Image = _vp.get_texture().get_image()
	if img.save_png(out.path_join(name)) != OK:
		push_error("DmgnumShots: save failed " + name)
