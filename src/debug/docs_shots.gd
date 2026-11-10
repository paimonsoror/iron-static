class_name DocsShots
extends Node
## Desktop capture harness of the README and codex pictures (docs true-up; reusable for the store screenshots, B1-06).
## Renders the production HUD, upgrade panel and BattleView, and the Home screen, into 1080x2400 SubViewports and saves
## PNGs, then quits. Needs a window (not --headless):
##   godot --path . --windowed --resolution 540x600 res://src/debug/docs_shots.tscn -- [--dx-out=build/docs_shots]
##   [--dx-only=wave1,numbers,crowd,intel_stats,intel_wave,burn,home_progress]
## Scenarios (the crowd, intel and burn ones are DEBUG scenarios: an invulnerable Cinder, a bot that buys with scrap and
## takes the first draft card, played to wave 20; the speed control shows 8x with the fall-back to 2x because a boss is
## alive):
##   draft          the patch draft (three family cards) over the battle at wave 10 (store screenshot)
##   upgrades       wave 13 with the CHASSIS tab open (store screenshot)
##   wave1          fresh deployment a few seconds in (the starting rows, 230 scrap); also saves tooltip (a row's
##                  formula tooltip open)
##   crowd          wave 20 with the boss hulk, damage numbers and the speed control in fall-back
##   intel_stats    the INTEL tab, STATS sub-tab, on the crowd state
##   intel_wave     the INTEL tab, WAVE sub-tab
##   burn           Cinder at 40 percent hull (skin burn band 2) with the STATS tab showing BURN HARDENING
##   numbers        wave 9 mid-fight, a frame with several readable damage numbers (a crit among them)
##   home_progress  Home with PURGE unlocked and selected, a best wave and some data

const DEFAULT_SIZE: Vector2i = Vector2i(1080, 2400)
## Typical phone cutout and gesture bar (left, top, right, bottom), as in the other harnesses.
const SAFE: Vector4 = Vector4(0.0, 110.0, 0.0, 70.0)
const CROWD_WAVE: int = 20
const DRAFT_WAVE: int = 10
const UPGRADES_WAVE: int = 13
const NUMBERS_WAVE: int = 9
const WAVE1_TICKS: int = 420
const MAX_FRAMES: int = 6000
const BANNER_FRAMES: int = 150
## Extra frames to wait for a crit number before settling for normal ones (a fresh profile has few crits).
const CRIT_WAIT_FRAMES: int = 60

var _out: String = "build/docs_shots"
var _size: Vector2i = DEFAULT_SIZE
var _speed: int = 8
var _only: PackedStringArray = PackedStringArray()


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--dx-out="):
			_out = a.get_slice("=", 1)
		elif a.begins_with("--dx-size="):
			var parts: PackedStringArray = a.get_slice("=", 1).split("x")
			if parts.size() == 2:
				_size = Vector2i(parts[0].to_int(), parts[1].to_int())
		elif a.begins_with("--dx-speed="):
			_speed = a.get_slice("=", 1).to_int()
		elif a.begins_with("--dx-only="):
			_only = a.get_slice("=", 1).split(",", false)
	DirAccess.make_dir_recursive_absolute(_out)
	Game.visual.set_accessibility("off", false)
	if _wanted("home_progress"):
		await _home_progress()
	if _wanted("wave1"):
		await _wave1()
	if _wanted("numbers"):
		await _numbers_scene()
	if _wanted("draft"):
		await _mid_scene(true)
	if _wanted("upgrades"):
		await _mid_scene(false)
	if _wanted("crowd") or _wanted("intel_stats") or _wanted("intel_wave") or _wanted("burn"):
		await _crowd_family()
	get_tree().quit()


func _wanted(shot_name: String) -> bool:
	return _only.is_empty() or _only.has(shot_name)


func _viewport() -> SubViewport:
	var vp := SubViewport.new()
	vp.size = _size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size_2d_override_stretch = false
	add_child(vp)
	return vp


func _save(vp: SubViewport, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	var path: String = _out.path_join(shot_name + ".png")
	if img.save_png(path) != OK:
		push_error("docs shot save failed: " + path)
	print("[DX] %s %dx%d" % [path, img.get_width(), img.get_height()])


func _home_progress() -> void:
	var vp: SubViewport = _viewport()
	var profile: PlayerProfile = PlayerProfile.fresh(0, "docs")
	profile.data = BigNum.from_int(1240)
	profile.runs_total = 9
	profile.best_wave["1"] = 24
	profile.best_wave_by_mode = {"purge": {"1": 11}}
	@warning_ignore("return_value_discarded")
	profile.unlock_mode("purge")
	@warning_ignore("return_value_discarded")
	profile.select_mode("purge")
	var home: HomeScreen = (load("res://src/ui/home/home_screen.tscn") as PackedScene).instantiate() as HomeScreen
	home.setup(profile)
	vp.add_child(home)
	home.size = Vector2(_size)
	home.apply_safe_margins(SAFE)
	home.enter()
	await get_tree().create_timer(0.8).timeout
	await _save(vp, "home_progress")
	vp.queue_free()
	await get_tree().process_frame


## A rig of the production battle screen: BattleView under the real HUD (which owns the upgrade panel).
func _rig(vp: SubViewport, world: SimWorld) -> Array:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(root)
	var battle: BattleView = (load("res://src/view/battle_view.tscn") as PackedScene).instantiate() as BattleView
	root.add_child(battle)
	var hud: Hud = (load("res://src/ui/hud.tscn") as PackedScene).instantiate() as Hud
	root.add_child(hud)
	hud.apply_safe_margins(SAFE)
	hud.field_rect_changed.connect(battle.set_field_rect)
	battle.layout(Vector2(_size))
	battle.bind(world)
	hud.upgrade_panel().bind(world)
	return [battle, hud]


func _wave1() -> void:
	var vp: SubViewport = _viewport()
	var world := SimWorld.new(SimConfigLoader.load_default(7))
	var rig: Array = _rig(vp, world)
	var battle: BattleView = rig[0]
	var hud: Hud = rig[1]
	for i: int in WAVE1_TICKS:
		world.step()
	# About 2.5 s of wall time so the wave banner has slid away and the beam has fired at the first arrivals.
	for i: int in 75:
		battle.render(0.5)
		hud.refresh(world, 100.0 + float(i) * 0.04)
		await get_tree().process_frame
	await _save(vp, "wave1")
	hud.upgrade_panel().row_at(0).toggle_tooltip()  # the formula tooltip of the first row
	for i: int in 6:
		battle.render(0.5)
		hud.refresh(world, 200.0 + float(i))
		hud.upgrade_panel().reflow()
		await get_tree().process_frame
	await _save(vp, "tooltip")
	vp.queue_free()
	await get_tree().process_frame


func _numbers_scene() -> void:
	var vp: SubViewport = _viewport()
	var world := SimWorld.new(SimConfigLoader.load_default(11))
	world.cinder.invulnerable = true
	var rig: Array = _rig(vp, world)
	var battle: BattleView = rig[0]
	var hud: Hud = rig[1]
	var bot := PolicyBot.new("all")
	var layer: DamageNumberLayer = battle.get_node("DamageNumbers")
	var frame: int = 0
	var found_at: int = -1
	while frame < MAX_FRAMES:
		for i: int in 2 if world.wave >= NUMBERS_WAVE else 40:
			if world.tick % 15 == 0:
				bot.think(world)
			@warning_ignore("return_value_discarded")
			PolicyBot.settle_draft(world)
			world.step()
		world.cinder.hp = world.cinder.max_hp
		battle.render(1.0)
		hud.refresh(world, 100.0 + float(frame) * 0.05)
		await get_tree().process_frame
		frame += 1
		if world.wave < NUMBERS_WAVE:
			continue
		if found_at < 0:
			found_at = frame
		if _numbers_ready(layer.model, frame - found_at >= CRIT_WAIT_FRAMES * 4):
			break
	print("[DX] numbers wave=%d live=%d frames=%d" % [world.wave, layer.model.live_count(), frame])
	await _save(vp, "numbers")
	vp.queue_free()
	await get_tree().process_frame


## The patch draft over the live battle: three family cards at the wave-10 patch (store screenshot; offers are staged).
func _mid_scene(draft: bool) -> void:
	var vp: SubViewport = _viewport()
	var world := SimWorld.new(SimConfigLoader.load_default(7))
	world.cinder.invulnerable = true
	var rig: Array = _rig(vp, world)
	var battle: BattleView = rig[0]
	var hud: Hud = rig[1]
	var bot := PolicyBot.new("all")
	var frame: int = 0
	var target: int = DRAFT_WAVE if draft else UPGRADES_WAVE
	while frame < MAX_FRAMES and not (world.wave >= target and (world.is_draft_open() or not draft)):
		world.cinder.hp = world.cinder.max_hp
		for i: int in 20:
			if world.tick % 15 == 0:
				bot.think(world)
			if world.wave < target or not draft:
				@warning_ignore("return_value_discarded")
				PolicyBot.settle_draft(world)
			if not world.is_draft_open():
				world.step()
		battle.render(1.0)
		hud.refresh(world, 100.0 + float(frame) * 0.05)
		await get_tree().process_frame
		frame += 1
	if not draft:
		@warning_ignore("return_value_discarded")
		hud.upgrade_panel().set_tab("chassis")
		for i: int in BANNER_FRAMES + 10:  # until the wave banner has slid away
			world.cinder.hp = world.cinder.max_hp
			for k: int in 2:
				if world.tick % 15 == 0:
					bot.think(world)
				@warning_ignore("return_value_discarded")
				PolicyBot.settle_draft(world)
				world.step()
			battle.render(0.5)
			hud.refresh(world, 300.0 + float(i))
			hud.upgrade_panel().reflow()
			await get_tree().process_frame
		await _save(vp, "upgrades")
		vp.queue_free()
		await get_tree().process_frame
		return
	var ids: Array[String] = []
	for d: PatchDef in world.config.patches:
		ids.append(d.id)
	var offers := PackedInt32Array()
	for id: String in ["patch_overcharge", "patch_plating", "patch_extraction"]:
		offers.append(ids.find(id))
	world.draft.offers = offers
	var overlay: DraftOverlay = (
		(load("res://src/ui/draft/draft_overlay.tscn") as PackedScene).instantiate() as DraftOverlay
	)
	overlay.reduce_motion = true
	vp.get_child(0).add_child(overlay)
	overlay.open(world)
	for i: int in 8:
		battle.render(0.5)
		await get_tree().process_frame
	await _save(vp, "draft")
	vp.queue_free()
	await get_tree().process_frame


func _crowd_family() -> void:
	var vp: SubViewport = _viewport()
	var world := SimWorld.new(SimConfigLoader.load_default(7))
	world.cinder.invulnerable = true
	var rig: Array = _rig(vp, world)
	var battle: BattleView = rig[0]
	var hud: Hud = rig[1]
	hud.set_best_timed(60)
	hud.set_speed(_speed)
	var bot := PolicyBot.new("all")
	var layer: DamageNumberLayer = battle.get_node("DamageNumbers")
	var frame: int = 0
	var near_frame: int = -1
	while frame < MAX_FRAMES:
		var near: bool = world.wave >= CROWD_WAVE
		if near and near_frame < 0:
			near_frame = frame
		world.cinder.hp = world.cinder.max_hp  # the debug Cinder takes hits but is kept topped up
		for i: int in 2 if near else 40:
			if world.tick % 15 == 0:
				bot.think(world)
			@warning_ignore("return_value_discarded")
			PolicyBot.settle_draft(world)
			if not world.is_over():
				world.step()
		battle.render(1.0)
		hud.refresh(world, 100.0 + float(frame) * 0.05)
		await get_tree().process_frame
		frame += 1
		# 150 frames after the boss wave starts the boss warning banner has slid away again.
		var settled: bool = near and frame - near_frame >= BANNER_FRAMES
		if (
			settled
			and world.alive_boss_count() > 0
			and _numbers_ready(layer.model, frame - near_frame >= BANNER_FRAMES + CRIT_WAIT_FRAMES)
		):
			break
	print(
		(
			"[DX] crowd wave=%d alive=%d boss=%d numbers=%d frames=%d"
			% [world.wave, world.enemies.alive_count, world.alive_boss_count(), layer.model.live_count(), frame]
		)
	)
	if _wanted("crowd"):
		await _save(vp, "crowd")
	var panel: UpgradePanel = hud.upgrade_panel()
	@warning_ignore("return_value_discarded")
	panel.set_tab("intel")
	if _wanted("intel_wave"):
		@warning_ignore("return_value_discarded")
		panel.intel_hub().set_sub("wave")
		await _settle(battle, hud, world, panel)
		await _save(vp, "intel_wave")
	@warning_ignore("return_value_discarded")
	panel.intel_hub().set_sub("stats")
	if _wanted("intel_stats"):
		await _settle(battle, hud, world, panel)
		await _save(vp, "intel_stats")
	if _wanted("burn"):
		world.cinder.hp = world.cinder.max_hp * 0.40
		world.cinder.invulnerable = false
		world.step()
		world.cinder.invulnerable = true
		await _settle(battle, hud, world, panel)
		var scroll: ScrollContainer = panel.find_child("Scroll", true, false) as ScrollContainer
		if scroll != null:  # the BURN HARDENING row sits at the end of the stats list
			scroll.scroll_vertical = 100000
		await _settle(battle, hud, world, panel)
		await _save(vp, "burn")
	vp.queue_free()
	await get_tree().process_frame


func _settle(battle: BattleView, hud: Hud, world: SimWorld, panel: UpgradePanel) -> void:
	for i: int in 10:
		battle.render(0.5)
		hud.refresh(world, 400.0 + float(i))
		panel.intel_hub().stats_panel().refresh()
		panel.intel_hub().wave_panel().refresh()
		panel.reflow()
		await get_tree().process_frame


## True when a crit number and another number are live, or (`give_up`) any four numbers are.
func _numbers_ready(model: DamageNumberModel, give_up: bool) -> bool:
	var enemy: int = 0
	var crits: int = 0
	for slot: int in DamageNumberModel.POOL:
		if not model.is_live(slot):
			continue
		var kind: int = model.kind_at(slot)
		if kind == DamageNumberModel.Kind.NORMAL:
			enemy += 1
		elif kind == DamageNumberModel.Kind.CRIT or kind == DamageNumberModel.Kind.OVERCRIT:
			enemy += 1
			crits += 1
	return (enemy >= 2 and crits >= 1) or (give_up and model.live_count() >= 4)
