class_name PaletteShots
extends Node
## Desktop capture harness for M4-24: one battle frame (BattleView + HUD, the same crowd and Cinder at 40% integrity)
## rendered in every accessibility palette, saved as PNGs plus one comparison sheet:
##   godot --path . --windowed --resolution 540x960 res://src/debug/palette_shots.tscn -- [--ps-out=build/m4_palettes]
## Frames: off, deuteranopia, protanopia, tritanopia, high contrast (off palette), deuteranopia + high contrast.

const SIZE: Vector2i = Vector2i(1080, 1920)
const CELL: Vector2i = Vector2i(360, 640)
const FRAMES: Array[Array] = [
	["off", false],
	["deuteranopia", false],
	["protanopia", false],
	["tritanopia", false],
	["off", true],
	["deuteranopia", true],
]
const CROWD_MIN: int = 45

var _world: SimWorld = null


func _ready() -> void:
	var out: String = "build/m4_palettes"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--ps-out="):
			out = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	_world = _build_world()
	var shots: Array[Image] = []
	for f: Array in FRAMES:
		var mode: String = f[0]
		var contrast: bool = f[1]
		var img: Image = await _shot(mode, contrast)
		var tag: String = "%s%s" % [mode, "_hc" if contrast else ""]
		img.save_png(out.path_join("palette_%s.png" % tag))
		shots.append(img)
	Game.visual.set_accessibility("off", false)
	_sheet(shots).save_jpg(out.path_join("palettes_sheet.jpg"), 0.85)
	print("[PALETTES] wrote %d frames, enemies alive %d" % [shots.size(), _world.enemies.alive_count])
	get_tree().quit()


func _build_world() -> SimWorld:
	var c := RunController.new()
	c.start_run(7)
	var w: SimWorld = c.world
	w.cinder.invulnerable = true
	var guard: int = 0
	while (w.enemies.alive_count < CROWD_MIN or w.wave < 4) and guard < 40000:
		w.step()
		guard += 1
	w.cinder.hp = w.cinder.max_hp * 0.4
	return w


func _shot(mode: String, contrast: bool) -> Image:
	Game.visual.set_accessibility(mode, contrast)
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
	hud.field_rect_changed.connect(battle.set_field_rect)
	battle.layout(Vector2(SIZE))
	battle.bind(_world)
	for i: int in 8:
		battle.render(0.5)
		hud.refresh(_world, 100.0 + float(i))
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	await get_tree().process_frame
	return img


func _sheet(shots: Array[Image]) -> Image:
	var cols: int = 3
	var rows: int = ceili(float(shots.size()) / float(cols))
	var sheet := Image.create(CELL.x * cols, CELL.y * rows, false, Image.FORMAT_RGB8)
	for i: int in shots.size():
		var img: Image = shots[i].duplicate()
		img.convert(Image.FORMAT_RGB8)
		img.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(
			img, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % cols) * CELL.x, floori(float(i) / float(cols)) * CELL.y)
		)
	return sheet
