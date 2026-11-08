class_name TitleFrame
extends Node
## IRON STATIC M3-25 title style frame (debug only, view only, no sim access): the smoky wasteland title at the real
## 1080 x 2400 layout and the 1990 x 1920 wide layout. Run it as the main scene of a debug build:
##   godot --path . res://src/debug/title_frame.tscn [-- --quality=low --debug-perf]
## (the `--title-frame` boot arg that Main honours is wired by the production task M3-28).
## Extra args: `--tf-shots[=dir]` renders the capture series into SubViewports and quits (desktop),
## `--tf-hide` hides the debug row, `--quality=high|mid|low`, `--reduce-motion`.

const PORTRAIT: Vector2 = Vector2(1080.0, 2400.0)
const WIDE: Vector2 = Vector2(1990.0, 1920.0)
const SAFE_TOP: float = 96.0
const SAFE_BOTTOM: float = 64.0
const LOGO_CENTER_Y: float = 540.0
const FADE_S: float = 0.6
const SETTLE_S: float = 1.2

var tier: VisualQuality.Tier = VisualQuality.Tier.HIGH
var reduce_motion: bool = false
var frame_id: String = "vanguard"
var scan_on: bool = true

var _host: Node = null
var _viewport: SubViewport = null
var _size: Vector2 = PORTRAIT
var _stage: TitleFrameStage = null
var _logo: TitleFrameLogo = null
var _buttons: TitleFrameButtons = null
var _overlay: ColorRect = null
var _fade: ColorRect = null
var _menu: TitleFrameMenu = null
var _t: float = 0.0
var _fade_t: float = 0.0
var _frozen: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var shots_dir: String = ""
	for a: String in args:
		if a.begins_with("--tf-shots"):
			shots_dir = a.get_slice("=", 1) if "=" in a else "build/title_frame"
	tier = VisualQuality.tier_from_args(args)
	reduce_motion = args.has("--reduce-motion")
	for a: String in args:
		if a.begins_with("--frame="):
			frame_id = a.get_slice("=", 1)
	_host = self
	if shots_dir != "":
		_viewport = SubViewport.new()
		_viewport.size = Vector2i(PORTRAIT)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_viewport)
		_host = _viewport
	_build()
	_apply_all()
	if args.has("--tf-hide") or shots_dir != "":
		_menu.set_shown(false)
	if shots_dir != "":
		_fade_t = FADE_S
		TitleFrameShots.run(self, shots_dir)
	else:
		get_viewport().size_changed.connect(_on_resized)
		_on_resized()


func _build() -> void:
	var art := Node2D.new()
	_host.add_child(art)
	_stage = TitleFrameStage.new()
	art.add_child(_stage)
	_stage.build()
	_stage.set_frame(frame_id)
	var ui := CanvasLayer.new()
	ui.layer = 1
	_host.add_child(ui)
	_logo = TitleFrameLogo.new()
	ui.add_child(_logo)
	_logo.setup()
	_logo.scale = Vector2.ONE * TitleFrameArt.LOGO_SCALE
	_buttons = TitleFrameButtons.new()
	ui.add_child(_buttons)
	_buttons.setup()
	_buttons.pressed.connect(_on_pressed)
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var om := ShaderMaterial.new()
	om.shader = load(TitleFrameArt.SHADER_OVERLAY) as Shader
	_overlay.material = om
	ui.add_child(_overlay)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 2
	_host.add_child(menu_layer)
	_menu = TitleFrameMenu.new()
	menu_layer.add_child(_menu)
	_menu.setup()
	_menu.action.connect(_on_action)


func _on_resized() -> void:
	layout(get_viewport().get_visible_rect().size)


## Positions everything for a viewport of `size` (base px; 1080 x 2400 portrait, 1990 x 1920 wide).
func layout(size: Vector2) -> void:
	_size = size
	_stage.layout(size)
	var squeeze: float = minf(size.y - PORTRAIT.y, 0.0)
	_logo.position = Vector2(size.x * 0.5, LOGO_CENTER_Y + squeeze * 0.25)
	var bs: Vector2 = TitleFrameButtons.block_size()
	_buttons.position = Vector2((size.x - bs.x) * 0.5, size.y - bs.y - SAFE_BOTTOM - 32.0)
	_overlay.size = size
	(_overlay.material as ShaderMaterial).set_shader_parameter("rect_px", size)
	_fade.size = size


func _apply_all() -> void:
	_stage.reduce_motion = reduce_motion
	_logo.reduce_motion = reduce_motion
	_stage.set_tier(tier)
	_overlay.visible = scan_on and tier == VisualQuality.Tier.HIGH
	_menu.set_label("MOTION", "MOTION " + ("off" if reduce_motion else "on"))
	_menu.set_label("SCAN", "SCAN " + ("on" if scan_on else "off"))
	_fade.visible = _fade_t < FADE_S


func _on_action(id: String) -> void:
	match id:
		"HIGH":
			tier = VisualQuality.Tier.HIGH
		"MID":
			tier = VisualQuality.Tier.MID
		"LOW":
			tier = VisualQuality.Tier.LOW
		"MOTION":
			reduce_motion = not reduce_motion
		"SCAN":
			scan_on = not scan_on
		"FLARE":
			_stage.start_flare()
		"GLITCH":
			_logo.force_tear()
		"VANGUARD", "BULWARK", "STRIKER":
			_stage.set_frame(id.to_lower())
		"HIDE":
			_menu.set_shown(false)
	_apply_all()


func _on_pressed(id: String) -> void:
	Log.info("[TITLE] pressed " + id)


func set_state(new_tier: VisualQuality.Tier, motion_off: bool, scan: bool) -> void:
	tier = new_tier
	reduce_motion = motion_off
	scan_on = scan
	_apply_all()


func stage() -> TitleFrameStage:
	return _stage


func logo() -> TitleFrameLogo:
	return _logo


func menu() -> TitleFrameMenu:
	return _menu


func host_viewport() -> SubViewport:
	return _viewport


func advance(dt: float) -> void:
	_t += dt
	_fade_t = minf(_fade_t + dt, FADE_S)
	var a: float = 1.0 - smoothstep(0.0, 1.0, _fade_t / FADE_S)
	_fade.color = Color(0.0, 0.0, 0.0, a)
	_fade.visible = a > 0.0
	_stage.tick(_t, dt)
	_logo.tick(_t, dt)


func _process(delta: float) -> void:
	if not _frozen:
		advance(delta)


func set_frozen(frozen: bool) -> void:
	_frozen = frozen


func view_time() -> float:
	return _t


func view_size() -> Vector2:
	return _size
