class_name StoreShots
extends Node
## Desktop capture harness of the menu-side store screenshots (B1-06): the Foundry, the Frame Bay, Results with NEW
## BEST, the title and Home with the mode picker, rendered into 1080x1920 SubViewports (9:16, the Play shape) from a
## profile with some progress. The battle ones come from `docs_shots.tscn --dx-size=1080x1920` (crowd, draft, wave1).
## Needs a window (not --headless):
##   godot --path . --windowed --resolution 540x600 res://src/debug/store_shots.tscn -- --no-save --mute
##   [--ss-out=build/store] [--ss-only=foundry,frames,results,title,home]

const SIZE: Vector2i = Vector2i(1080, 1920)
## Typical phone cutout and gesture bar (left, top, right, bottom), as in the other harnesses.
const SAFE: Vector4 = Vector4(0.0, 110.0, 0.0, 70.0)

var _out: String = "build/store"
var _only: PackedStringArray = PackedStringArray()


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ss-out="):
			_out = a.get_slice("=", 1)
		elif a.begins_with("--ss-only="):
			_only = a.get_slice("=", 1).split(",", false)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.visual.set_accessibility("off", false)
	if _wanted("foundry"):
		await _foundry()
	if _wanted("frames"):
		await _frames()
	if _wanted("results"):
		await _results()
	if _wanted("title"):
		await _title()
	if _wanted("home"):
		await _home()
	get_tree().quit()


func _wanted(shot_name: String) -> bool:
	return _only.is_empty() or _only.has(shot_name)


func _viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size_2d_override_stretch = false
	add_child(vp)
	var base := ColorRect.new()
	base.color = Palette.VOID
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(base)
	return vp


func _save(vp: SubViewport, shot_name: String, frames: int = 8) -> void:
	for i: int in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var path: String = _out.path_join(shot_name + ".png")
	if img.save_png(path) != OK:
		push_error("store shot save failed: " + path)
	print("[SS] %s %dx%d" % [path, img.get_width(), img.get_height()])
	vp.queue_free()
	await get_tree().process_frame


## A mid-game profile: a few runs banked, PURGE unlocked, some Foundry levels, the BULWARK frame unlocked.
func _profile() -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.fresh(0, "store")
	p.data = BigNum.from_int(4820)
	p.runs_total = 14
	p.best_wave["1"] = 31
	p.best_wave_by_mode = {"purge": {"1": 17}}
	@warning_ignore("return_value_discarded")
	p.unlock_mode("purge")
	@warning_ignore("return_value_discarded")
	p.select_mode("purge")
	p.set_foundry_level("laser_output", 14)
	p.set_foundry_level("cycle_rate", 9)
	p.set_foundry_level("hull_integrity", 11)
	p.set_foundry_level("nano_repair", 6)
	@warning_ignore("return_value_discarded")
	FoundryIntroFlag.set_hidden(p, true)
	return p


func _foundry() -> void:
	var vp: SubViewport = _viewport()
	var s: FoundryScreen = (
		(load("res://src/ui/foundry/foundry_screen.tscn") as PackedScene).instantiate() as FoundryScreen
	)
	s.use_profile(_profile())
	vp.add_child(s)
	s.size = Vector2(SIZE)
	s.apply_safe_margins(SAFE)
	s.enter()
	await _save(vp, "foundry")


func _frames() -> void:
	var p: PlayerProfile = Game.profile()
	@warning_ignore("return_value_discarded")
	p.unlock_frame("bulwark")
	var vp: SubViewport = _viewport()
	var s: FrameBay = (load("res://src/ui/frames/frame_bay.tscn") as PackedScene).instantiate() as FrameBay
	vp.add_child(s)
	s.size = Vector2(SIZE)
	s.apply_safe_margins(SAFE)
	s.enter()
	s.page(1)
	await _save(vp, "frames")


func _results() -> void:
	var c := RunController.new()
	@warning_ignore("return_value_discarded")
	c.start_run(7)
	@warning_ignore("return_value_discarded")
	c.fast_forward(60000)
	var w: SimWorld = c.world
	w.run.death_cause = 4
	w.run.death_wave = 32
	w.tick = 912 * Ticks.TICK_RATE
	w.run.kills = 0
	var kills: Array[int] = [412, 96, 40, 21, 1]
	for i: int in kills.size():
		w.run.kills_by_type[i] = kills[i]
		w.run.kills += kills[i]
	w.run.scrap_earned = 41800.0
	w.economy.data_run = BigNum.from_int(84 * 32)
	var info := BankedInfo.new()
	info.has_bank = true
	info.mode = "timed"
	info.previous_best = 29
	info.new_best = 32
	info.data_total = BigNum.from_int(4820)
	info.foundry_unlocked = true
	info.affordable_count = 4
	var vp: SubViewport = _viewport()
	var overlay: ResultsOverlay = (
		(load("res://src/ui/results_overlay.tscn") as PackedScene).instantiate() as ResultsOverlay
	)
	overlay.reduce_motion = true
	vp.add_child(overlay)
	overlay.show_results(w, info)
	await _save(vp, "results")


func _title() -> void:
	var vp: SubViewport = _viewport()
	var s: TitleScreen = (load("res://src/ui/title/title_screen.tscn") as PackedScene).instantiate() as TitleScreen
	vp.add_child(s)
	s.show_state(VisualQuality.Tier.HIGH, false, true, "vanguard")
	await get_tree().create_timer(3.4).timeout
	await _save(vp, "title")


func _home() -> void:
	var vp: SubViewport = _viewport()
	var home: HomeScreen = (load("res://src/ui/home/home_screen.tscn") as PackedScene).instantiate() as HomeScreen
	home.setup(_profile())
	vp.add_child(home)
	home.size = Vector2(SIZE)
	home.apply_safe_margins(SAFE)
	home.enter()
	await get_tree().create_timer(0.8).timeout
	await _save(vp, "home")
