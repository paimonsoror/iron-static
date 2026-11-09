class_name HomeDiorama
extends Control
## The Home backdrop (M3-15): the arena floor with its slow sweep and Cinder at rest (band 0, selected frame
## variant, visor drifting), drawn by the same `ArenaBackground` and `CinderView` the battle uses, standalone and
## without any MultiMesh. A full-rect, input-ignoring, clipped control; the screen tells it where Cinder stands
## (`place`) and ticks it while visible. Reduce motion freezes the sweep, the drift and the rig's animation.

const ARENA_RADIUS_M: float = 52.0
const AIM_REST: float = -PI * 0.5
const AIM_DRIFT: float = 0.45
const AIM_SPEED: float = 0.35

var world: Node2D = null
var arena: ArenaBackground = null
var cinder: CinderView = null
var _clock_s: float = 0.0
var _focus := Vector2.ZERO
var _rect_size := Vector2.ZERO
var _visual: VisualSettings = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world = Node2D.new()
	add_child(world)
	arena = ArenaBackground.new()
	world.add_child(arena)
	cinder = CinderView.new()
	world.add_child(cinder)
	set_visual(Game.visual)
	cinder.set_state(1.0, 0, AIM_REST, 0.0)


func set_visual(settings: VisualSettings) -> void:
	_visual = settings
	arena.setup_visual(settings)
	cinder.visual = settings


## Which frame variant of the rig Cinder wears (`vanguard`, `bulwark`, `striker`).
func set_frame(id: String) -> void:
	cinder.set_frame(id)


## Cinder stands at `at` (this control's pixels) with the emitter ring radius `radius_px`; the arena floor fills
## the whole control around her.
func place(at: Vector2, radius_px: float) -> void:
	if at == _focus and size == _rect_size and is_equal_approx(radius_px, cinder.radius_px):
		return
	_focus = at
	_rect_size = size
	world.position = at
	cinder.radius_px = radius_px
	arena.setup(ViewMath.px_per_m(1080.0), ARENA_RADIUS_M, Rect2(-at, size))
	arena.snap_haze()


func focus_point() -> Vector2:
	return _focus


func reduced() -> bool:
	return _visual != null and _visual.reduce_motion


## Advances the idle animation by `delta` seconds (called by the screen while it is visible).
func tick(delta: float) -> void:
	if reduced():
		_clock_s = 0.0
	else:
		_clock_s += delta
	var aim: float = AIM_REST + AIM_DRIFT * sin(_clock_s * AIM_SPEED * TAU)
	arena.apply_state(_clock_s, 0, 0)
	cinder.set_state(1.0, 0, aim, _clock_s)
