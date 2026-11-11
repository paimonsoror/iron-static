class_name MenuShots
extends Node
## Desktop capture harness of the menu screens (side-margin pass): renders Home (fresh profile), the Frame Bay, the
## Foundry and Settings into SubViewports and saves PNGs, then quits:
##   godot --path . --windowed --resolution 540x600 res://src/debug/menu_shots.tscn -- [--ms-out=build/m4_polish]
## `--ms-record` renders only Home with the RECORD tab and the Service Record (top, middle, bottom) at 1080x1920
## and 1080x2400.

const PORTRAIT: Vector2i = Vector2i(1080, 2400)
const SHORT: Vector2i = Vector2i(1080, 1920)
const WIDE: Vector2i = Vector2i(1990, 1920)


func _ready() -> void:
	var out: String = "build/m4_polish"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ms-out="):
			out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	if OS.get_cmdline_user_args().has("--ms-record"):
		await _record_shots(out)
		get_tree().quit()
		return
	await _shot(out, "home", "res://src/ui/home/home_screen.tscn", PORTRAIT)
	await _shot(out, "home_wide", "res://src/ui/home/home_screen.tscn", WIDE)
	await _shot(out, "frame_bay", "res://src/ui/frames/frame_bay.tscn", PORTRAIT)
	await _shot(out, "foundry", "res://src/ui/foundry/foundry_screen.tscn", PORTRAIT)
	await _shot(out, "settings", "res://src/ui/settings/settings_screen.tscn", PORTRAIT)
	await _shot(out, "settings_1920", "res://src/ui/settings/settings_screen.tscn", SHORT)
	await _shot(out, "title", "res://src/ui/title/title_screen.tscn", PORTRAIT)
	await _dialog(out)
	get_tree().quit()


func _viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var base := ColorRect.new()
	base.color = Palette.VOID
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(base)
	return vp


func _save(vp: SubViewport, out: String, shot_name: String) -> void:
	for i: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	if img.save_png(out.path_join("menu_%s.png" % shot_name)) != OK:
		push_error("menu shot save failed: " + shot_name)
	vp.queue_free()
	await get_tree().process_frame


func _shot(out: String, shot_name: String, scene: String, size: Vector2i) -> void:
	var vp: SubViewport = _viewport(size)
	var s: MenuScreen = (load(scene) as PackedScene).instantiate() as MenuScreen
	if s is HomeScreen:
		(s as HomeScreen).setup(PlayerProfile.fresh(0, "shots"))
	vp.add_child(s)
	s.size = Vector2(size)
	s.enter()
	await _save(vp, out, shot_name)


func _dialog(out: String) -> void:
	var vp: SubViewport = _viewport(PORTRAIT)
	var d := ConfirmDialog.new()
	vp.add_child(d)
	d.size = Vector2(PORTRAIT)
	d.open("ABORT MISSION?", "This ends the run and banks what you earned.", "ABORT", "CANCEL")
	await _save(vp, out, "confirm")


## A profile with ten banked deployments and a lifetime record of plausible size (captures only).
func _record_profile() -> PlayerProfile:
	var p := PlayerProfile.fresh(1794268800, "shots")
	p.runs_total = 13
	p.best_wave["1"] = 31
	p.best_wave_by_mode["purge"] = {"1": 12}
	p.lifetime_data = BigNum.from_float(48200.0)
	p.data = BigNum.from_float(3100.0)
	p.foundry = {"laser_output": 14, "cycle_rate": 9, "hull_integrity": 11, "nano_repair": 4}
	ServiceRecord.ensure(p, FakeClock.new(1794268800))
	for k: int in 10:
		var t := RunTotals.new()
		t.detail = RunTotals.Detail.FULL
		t.mode = "timed" if k % 3 != 0 else "purge"
		t.frame_id = "vanguard" if k < 7 else "striker"
		t.wave = 14 + 2 * k
		t.waves_cleared = t.wave - 1
		t.ticks = 30 * (400 + 90 * k)
		t.kills = {"skitter": 410 + 30 * k, "dart": 160 + 20 * k, "walker": 70 + 9 * k, "lancer": 35 + 5 * k}
		if k % 2 == 1:
			t.kills["boss_hulk"] = 1
			t.bosses = 1
		t.shots = 2100 + 150 * k
		t.crits = 380 + 30 * k
		t.hit_max = 9800 + 1200 * k
		t.hull = 3200 + 260 * k
		t.damage = BigNum.from_float(3.2e6 * float(k + 1))
		t.upgrades = 90 + 8 * k
		t.patches = 3 + floori(float(k) / 3.0)
		t.scrap_in = BigNum.from_float(2.1e7 * float(k + 1))
		t.scrap_out = BigNum.from_float(1.9e7 * float(k + 1))
		ServiceRecord.commit_run(p, t)
	ServiceRecord.note_seconds(p, 4 * 3600 + 37 * 60 + 12)
	return p


func _record_shots(out: String) -> void:
	var p: PlayerProfile = _record_profile()
	for size: Vector2i in [SHORT, PORTRAIT]:
		var tag: String = "%d" % size.y
		var vp: SubViewport = _viewport(size)
		var home: HomeScreen = (load("res://src/ui/home/home_screen.tscn") as PackedScene).instantiate() as HomeScreen
		home.setup(p)
		vp.add_child(home)
		home.size = Vector2(size)
		home.enter()
		await _save(vp, out, "record_home_" + tag)
		for scrolled: int in [0, 1, 2]:
			var vp2: SubViewport = _viewport(size)
			var rec: ServiceRecordScreen = (
				(load("res://src/ui/record/service_record_screen.tscn") as PackedScene).instantiate()
				as ServiceRecordScreen
			)
			rec.setup(p)
			vp2.add_child(rec)
			rec.size = Vector2(size)
			rec.enter()
			for i: int in 4:
				await get_tree().process_frame
			var bar: ScrollBar = rec.scroll.get_v_scroll_bar()
			rec.scroll.scroll_vertical = [0, int(bar.max_value * 0.45), int(bar.max_value)][scrolled]
			await _save(vp2, out, "record_%s_%d" % [tag, scrolled])
