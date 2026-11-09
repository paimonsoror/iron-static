class_name ResultsShots
extends Node
## Desktop capture harness of the image-first results screen (M4). Renders the production `ResultsOverlay` into a
## SubViewport for scripted finished runs and saves PNGs, then quits:
##   godot --path . --windowed --resolution 540x600 res://src/debug/results_shots.tscn -- [--rs-out=build/m4_results]
## Shots: a TIMED death by a skitter, a PURGE death by the boss with NEW BEST and a mode unlock badge, the same with
## a frame badge and the save warning on the wide 1990 x 1920 layout, and a no-bank debug run.

const SCENE: String = "res://src/ui/results_overlay.tscn"
const PORTRAIT: Vector2i = Vector2i(1080, 2400)
const WIDE: Vector2i = Vector2i(1990, 1920)
const SKITTER: int = 0
const DART: int = 1
const WALKER: int = 2
const LANCER: int = 3
const BOSS: int = 4

var _world_out: SimWorld = null
var _info_out: BankedInfo = null


func _ready() -> void:
	var out: String = "build/m4_results"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--rs-out="):
			out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	_timed()
	await _shot(out, "timed_skitter", PORTRAIT, true)
	_purge(false)
	await _shot(out, "purge_boss_new_best", PORTRAIT, true)
	_purge(true)
	await _shot(out, "purge_boss_wide_all_badges", WIDE, true)
	await _shot(out, "debug_run_no_bank", PORTRAIT, false)
	get_tree().quit()


func _world(cause: int, wave: int, kills: Array[int], ticks: int) -> SimWorld:
	var c := RunController.new()
	c.start_run(7)
	c.fast_forward(60000)
	var w: SimWorld = c.world
	w.run.death_cause = cause
	w.run.death_wave = wave
	w.tick = ticks
	w.run.kills = 0
	for i: int in kills.size():
		w.run.kills_by_type[i] = kills[i]
		w.run.kills += kills[i]
	w.run.scrap_earned = 4180.0
	w.economy.data_run = BigNum.from_int(84 * wave)
	return w


func _timed() -> void:
	var w: SimWorld = _world(SKITTER, 8, [44, 12, 5, 3, 0], 189 * Ticks.TICK_RATE)
	var info := _info("timed", 20, 8)
	_world_out = w
	_info_out = info


func _purge(all: bool) -> void:
	var w: SimWorld = _world(BOSS, 31, [412, 96, 40, 21, 1], 912 * Ticks.TICK_RATE)
	var info := _info("purge", 29, 31)
	info.unlocked_modes = ["purge"]
	if all:
		info.unlocked_frames = ["bulwark"]
		info.save_failed = true
	_world_out = w
	_info_out = info


func _info(mode: String, prev: int, wave: int) -> BankedInfo:
	var info := BankedInfo.new()
	info.has_bank = true
	info.mode = mode
	info.previous_best = prev
	info.new_best = maxi(prev, wave)
	info.data_total = BigNum.from_int(381)
	info.foundry_unlocked = true
	info.affordable_count = 4
	return info


func _shot(out: String, shot_name: String, size: Vector2i, scripted: bool) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var base := ColorRect.new()
	base.color = Palette.VOID
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(base)
	var packed: PackedScene = load(SCENE) as PackedScene
	var overlay: ResultsOverlay = packed.instantiate() as ResultsOverlay
	overlay.reduce_motion = true
	vp.add_child(overlay)
	if not scripted:
		overlay.show_results(_world(LANCER, 5, [20, 4, 0, 1, 0], 120 * Ticks.TICK_RATE), BankedInfo.new())
	else:
		overlay.show_results(_world_out, _info_out)
	for i: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var card: Control = overlay.get_node("%Card")
	print("[RESULTS] %s card=%s screen=%s" % [shot_name, str(Rect2(card.global_position, card.size)), str(size)])
	var img: Image = vp.get_texture().get_image()
	if img.save_png(out.path_join("results_%s.png" % shot_name)) != OK:
		push_error("results shot save failed: " + shot_name)
	vp.queue_free()
	await get_tree().process_frame
