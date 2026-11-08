class_name StyleFrame
extends Node
## IRON STATIC V1-01 style frame (launch arg `--style-frame`, debug builds only): the new SVG art composed at the
## real 1080 x 2400 layout with a fixed formation, FX and a styled HUD mock. View only, no sim access.
## Extra args: `--sf-shots[=dir]` renders a capture series into a 1080x2400 SubViewport and quits (desktop),
## `--sf-hide` starts with the debug rows hidden, `--debug-perf` emits [PERF] lines every 10 s.

const SIZE: Vector2 = Vector2(1080, 2400)
const BATTLE: Rect2 = Rect2(0, 0, 1080, 1344)
const CENTER: Vector2 = Vector2(540, 672)
const BODY_R: Array[float] = [32.0, 28.0, 70.0, 36.0]
const PERF_PERIOD_S: float = 10.0
const LOOKS: Array[String] = ["NEW", "OLD", "SPLIT"]

var band: int = 0
var density: int = 40
var clumped: bool = false
var scan_on: bool = true
var glow_on: bool = true
var cam32: bool = true
var look: int = 0
var env_on: bool = false

var _host: Node = null
var _viewport: SubViewport = null
var _world: Node2D = null
var _crowd: StyleFrameCrowd = null
var _cinder: StyleFrameCinder = null
var _fx: StyleFrameFx = null
var _old: StyleFrameOld = null
var _old_world: Node2D = null
var _new_clip: Control = null
var _old_clip: Control = null
var _arena: ColorRect = null
var _floor: Sprite2D = null
var _hud: CanvasLayer = null
var _menu: StyleFrameMenu = null
var _env: WorldEnvironment = null
var _stats: DebugStats = DebugStats.new(60)
var _since_perf: float = 0.0
var _perf: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_perf = args.has("--debug-perf")
	var shots_dir: String = ""
	for a: String in args:
		if a.begins_with("--sf-shots"):
			shots_dir = a.get_slice("=", 1) if "=" in a else "build/style_frame"
	_host = self
	if shots_dir != "":
		_viewport = SubViewport.new()
		_viewport.size = Vector2i(1080, 2400)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_viewport)
		_host = _viewport
	_build()
	_apply_all()
	if args.has("--sf-hide"):
		_menu.set_hidden(true)
	if shots_dir != "":
		_run_shots(shots_dir)


func _build() -> void:
	var stage := Node2D.new()
	_host.add_child(stage)
	_floor = Sprite2D.new()
	var floor_sprite: Sprite2D = _floor
	floor_sprite.texture = StyleFrameArt.tex("arena_floor")
	floor_sprite.position = CENTER
	stage.add_child(floor_sprite)
	_new_clip = _clip(stage)
	_world = Node2D.new()
	_world.position = CENTER
	_new_clip.add_child(_world)
	_cinder = StyleFrameCinder.new()
	_crowd = StyleFrameCrowd.new()
	_fx = StyleFrameFx.new()
	_world.add_child(_crowd)
	_world.add_child(_cinder)
	_world.add_child(_fx)
	_old_clip = _clip(stage)
	_old_world = Node2D.new()
	_old_clip.add_child(_old_world)
	_old = StyleFrameOld.new()
	_old_world.add_child(_old)
	_arena = ColorRect.new()
	_arena.size = BATTLE.size
	_arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(StyleFrameArt.SHADER_ARENA) as Shader
	_arena.material = mat
	stage.add_child(_arena)
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 1
	_hud = hud_layer
	_host.add_child(hud_layer)
	hud_layer.add_child(StyleFrameHud.new())
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 2
	_host.add_child(menu_layer)
	_menu = StyleFrameMenu.new()
	_menu.action.connect(_on_action)
	menu_layer.add_child(_menu)


func _clip(parent: Node2D) -> Control:
	var c := Control.new()
	c.clip_contents = true
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _on_action(id: String) -> void:
	match id:
		"B0", "B1", "B2", "B3":
			band = int(id.substr(1))
		"N40":
			density = 40
		"N100":
			density = 100
		"N165":
			density = 165
		"CLUMP":
			clumped = not clumped
		"SCAN":
			scan_on = not scan_on
		"GLOW":
			glow_on = not glow_on
		"CAM":
			cam32 = not cam32
		"LOOK":
			look = (look + 1) % LOOKS.size()
		"ENV":
			env_on = not env_on
		"HIDE":
			_menu.set_hidden(true)
			return
		"SHOW":
			_menu.set_hidden(false)
			return
	_apply_all()


func _apply_all() -> void:
	var ppm: float = 33.75 if cam32 else 28.4
	var k: float = ppm / 33.75
	_world.scale = Vector2(k, k)
	_cinder.build(band)
	_cinder.glow_on = glow_on
	_crowd.set_formation(density, clumped)
	_crowd.set_glow(glow_on)
	var meas: bool = density == 4
	_floor.visible = not meas
	_arena.visible = not meas
	_hud.visible = not meas
	_fx.visible = not meas
	_old.cinder_band = band
	var bosses: Array[Vector2] = []
	bosses.assign(StyleFrameLayout.BOSS_POS)
	_old.set_formation(_crowd.layout, bosses, band)
	_place_beams()
	_apply_look()
	var m: ShaderMaterial = _arena.material as ShaderMaterial
	m.set_shader_parameter("px_per_m", ppm)
	m.set_shader_parameter("scan_alpha", 0.06 if scan_on else 0.0)
	m.set_shader_parameter("grid_fade", 0.0 if density > 100 else 1.0)
	_apply_env()
	_menu.set_label("CLUMP", "CLUMP" if not clumped else "RING")
	_menu.set_label("SCAN", "SCAN " + ("on" if scan_on else "off"))
	_menu.set_label("GLOW", "GLOW " + ("on" if glow_on else "off"))
	_menu.set_label("CAM", "CAM " + ("32" if cam32 else "38"))
	_menu.set_label("LOOK", "LOOK " + LOOKS[look])
	_menu.set_label("ENV", "ENV " + ("on" if env_on else "off"))
	_stats = DebugStats.new(60)
	Log.info(
		(
			"[SF] band=%d n=%d clumped=%s scan=%s glow=%s cam=%s look=%s env=%s"
			% [band, density, clumped, scan_on, glow_on, cam32, LOOKS[look], env_on]
		)
	)


func _apply_look() -> void:
	var new_w: float = BATTLE.size.x
	_new_clip.visible = look != 1
	_old_clip.visible = look != 0
	if look == 2:
		new_w = 540.0
		_old_clip.position = Vector2(540, 0)
		_old_clip.size = Vector2(540, BATTLE.size.y)
		_old_world.position = Vector2(0, CENTER.y)
	else:
		_old_clip.position = Vector2.ZERO
		_old_clip.size = BATTLE.size
		_old_world.position = CENTER
	_new_clip.size = Vector2(new_w, BATTLE.size.y)
	_new_clip.position = Vector2.ZERO


func _place_beams() -> void:
	var starts := PackedVector2Array()
	var ends := PackedVector2Array()
	var used: PackedInt32Array = PackedInt32Array()
	var lay: StyleFrameLayout = _crowd.layout
	for e: int in 3:
		var from: Vector2 = StyleFrameCinder.emitter_pos(e)
		var best: int = -1
		var best_score: float = 1.0e9
		for i: int in lay.pos.size():
			var d: float = lay.pos[i].length()
			if d < 230.0 or d > 560.0 or used.has(i):
				continue
			var score: float = absf(from.angle_to(lay.pos[i])) * 300.0 + d * 0.3
			if score < best_score:
				best_score = score
				best = i
		if best < 0:
			continue
		used.append(best)
		var p: Vector2 = lay.pos[best]
		starts.append(from)
		ends.append(p + (-p).normalized() * 0.6 * BODY_R[lay.types[best]])
	_fx.set_beams(starts, ends)


func _apply_env() -> void:
	if _env != null:
		_env.queue_free()
		_env = null
	if not env_on:
		return
	var e := Environment.new()
	e.background_mode = Environment.BG_CANVAS
	e.glow_enabled = true
	e.glow_hdr_threshold = 0.7
	e.glow_intensity = 0.9
	e.glow_bloom = 0.1
	e.background_canvas_max_layer = 0
	_env = WorldEnvironment.new()
	_env.environment = e
	_host.add_child(_env)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_stats.add(1.0 / delta)
	_since_perf += delta
	if _since_perf >= PERF_PERIOD_S:
		_since_perf = 0.0
		if _perf:
			var line: String = "[PERF] fps=%.1f min=%.1f tick_ms=0.00 enemies=%d thr=0 lost=0 sf_env=%s sf_glow=%s sf_look=%s"
			Log.info(line % [_stats.period_average(), _stats.period_min(), density, env_on, glow_on, LOOKS[look]])
		_stats.reset_period()


func _shot(out: String, shot_name: String) -> void:
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var img: Image = _viewport.get_texture().get_image()
	img.save_png(out.path_join("sf_%s.png" % shot_name))


func _run_shots(out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	_menu.set_hidden(true)
	# name, band, density, clumped, glow, env, scan, look, cam32
	var plan: Array[Array] = [
		["40", 0, 40, false, true, false, true, 0, true],
		["b3", 3, 40, false, true, false, true, 0, true],
		["100", 0, 100, false, true, false, true, 0, true],
		["165", 0, 165, false, true, false, true, 0, true],
		["165_clump", 0, 165, true, true, false, true, 0, true],
		["noglow", 0, 40, false, false, false, true, 0, true],
		["env", 0, 40, false, true, true, true, 0, true],
		["noscan", 0, 40, false, true, false, false, 0, true],
		["split", 0, 40, false, true, false, true, 2, true],
		["old", 0, 40, false, true, false, true, 1, true],
		["cam38", 0, 40, false, true, false, true, 0, false],
		["measure", 0, 4, false, false, false, false, 0, true],
	]
	for p: Array in plan:
		band = p[1]
		density = p[2]
		clumped = p[3]
		glow_on = p[4]
		env_on = p[5]
		scan_on = p[6]
		look = p[7]
		cam32 = p[8]
		_apply_all()
		var nm: String = p[0]
		await _shot(out, nm)
	get_tree().quit()
