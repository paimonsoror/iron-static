class_name TitleFrame
extends Node
## Debug harness of the production title screen (M3-28; it began as the M3-25 style frame). Hosts the real
## `TitleScreen` scene at the 1080 x 2400 portrait or 1990 x 1920 wide layout:
##   godot --path . res://src/debug/title_frame.tscn [-- --quality=low --reduce-motion --frame=bulwark --tf-continue]
## `--tf-shots[=dir]` renders the capture series into a SubViewport, writes metrics.txt and quits (desktop only).
## `--tf-continue` shows the CONTINUE row (a profile with progress).
## `--tf-banner[=dir]` renders the README banner (see `TitleBanner`) and quits (desktop only).

const SCENE: String = "res://src/ui/title/title_screen.tscn"
const PORTRAIT: Vector2 = Vector2(1080.0, 2400.0)
const WIDE: Vector2 = Vector2(1990.0, 1920.0)

var _viewport: SubViewport = null
var _screen: TitleScreen = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var shots_dir: String = ""
	var banner: bool = false
	var frame_id: String = "vanguard"
	for a: String in args:
		if a.begins_with("--tf-shots") or a.begins_with("--tf-banner"):
			shots_dir = a.get_slice("=", 1) if "=" in a else "build/title_frame"
			banner = a.begins_with("--tf-banner")
		if a.begins_with("--frame="):
			frame_id = a.get_slice("=", 1)
	var host: Node = self
	if shots_dir != "":
		_viewport = SubViewport.new()
		_viewport.size = Vector2i(PORTRAIT)
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(_viewport)
		host = _viewport
	var packed: PackedScene = load(SCENE) as PackedScene
	_screen = packed.instantiate() as TitleScreen
	host.add_child(_screen)
	var tier: VisualQuality.Tier = VisualQuality.tier_from_args(args)
	_screen.show_state(tier, args.has("--reduce-motion"), args.has("--tf-continue"), frame_id)
	if banner:
		TitleBanner.run(self, shots_dir)
	elif shots_dir != "":
		TitleFrameShots.run(self, shots_dir)


func screen() -> TitleScreen:
	return _screen


func host_viewport() -> SubViewport:
	return _viewport
