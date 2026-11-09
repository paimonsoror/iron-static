class_name Vt5TierUpShots
extends Node
## VT-5 desktop check: the PRODUCTION tier-up moment (TierUpDirector, Cinder flash, TierBanner) in a real battle frame
## with the real HUD and upgrade rows. Needs a window:
##   godot --path . --windowed --resolution 540x960 res://src/debug/vt5_tier_up_shots.tscn -- --vt5-out=<dir>
##   [--vt5-review=<file.jpg>]
## Buys laser output MK II in a crowded wave and captures the frame 0.2 s later (flash mid-expansion, banner settled).

const SIZE: Vector2i = Vector2i(1080, 1920)
const REVIEW_W: int = 720
const CAPTURE_AFTER_S: float = 0.2

var _out: String = ""
var _review: String = ""


func _ready() -> void:
	_out = ProjectSettings.globalize_path("res://build/vt5")
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--vt5-out="):
			_out = a.get_slice("=", 1)
		if a.begins_with("--vt5-review="):
			_review = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(_out)
	var c := RunController.new()
	c.start_run(7)
	var w: SimWorld = c.world
	w.cinder.invulnerable = true
	var guard: int = 0
	while (w.enemies.alive_count < 20 or w.wave < 4) and guard < 40000:
		w.step()
		guard += 1
	w.run_levels[0] = 4
	w.economy.scrap = BigNum.from_int(5000)
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(root)
	var battle: BattleView = (load("res://src/view/battle_view.tscn") as PackedScene).instantiate() as BattleView
	root.add_child(battle)
	var hud: Hud = (load("res://src/ui/hud.tscn") as PackedScene).instantiate() as Hud
	root.add_child(hud)
	var banner := TierBanner.new()
	root.add_child(banner)
	hud.field_rect_changed.connect(battle.set_field_rect)
	hud.field_rect_changed.connect(banner.set_field_rect)
	battle.tier_banner_requested.connect(banner.play_moment)
	battle.layout(Vector2(SIZE))
	battle.bind(w)
	for i: int in 8:
		battle.render(0.5)
		hud.refresh(w, 100.0 + float(i))
		await get_tree().process_frame
	# The purchase: level 4 -> 5 crosses MK II.
	@warning_ignore("return_value_discarded")
	UpgradeSystem.buy(w, 0, 1)
	var t0: float = Time.get_ticks_msec() / 1000.0
	var f: int = 0
	while Time.get_ticks_msec() / 1000.0 - t0 < CAPTURE_AFTER_S:
		battle.render(0.5)
		hud.refresh(w, 200.0 + float(f))
		f += 1
		await get_tree().process_frame
	battle.render(0.5)
	hud.refresh(w, 300.0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	img.save_png(_out.path_join("vt5_tier_up.png"))
	print("[VT5] banner playing=%s title=%s frames=%d" % [banner.is_playing(), banner.title_text(), f])
	if _review != "":
		var j: Image = img.duplicate()
		j.convert(Image.FORMAT_RGB8)
		j.resize(
			REVIEW_W, roundi(float(j.get_height()) * float(REVIEW_W) / float(j.get_width())), Image.INTERPOLATE_LANCZOS
		)
		j.save_jpg(_review, 0.88)
	get_tree().quit()
