class_name StyleFrameOld
extends Node2D
## The M1/M2 procedural look (ShapeMeshes + CinderView) at the old scale (38 m camera = 28.4 px/m, hit radius,
## no stand-off) for the side-by-side toggle. Origin = Cinder. Fed with the same formation as the new look.

const OLD_PX_PER_M: float = 28.4
const RADII_M: Array[float] = [0.6, 0.5, 1.4, 0.7]
const SHAPES: Array[String] = ["skitter", "dart", "walker", "lancer"]
const STROKE_PX: float = 2.5

var cinder_band: int = 0
var _time: float = 0.0
var _cinder: CinderView = null
var _mms: Array[MultiMesh] = []
var _boss_mm: MultiMesh = null


func _ready() -> void:
	for t: int in SHAPES.size():
		_mms.append(_make_mm(SHAPES[t], RADII_M[t]))
	_boss_mm = _make_mm("boss_hulk", 3.0)
	_cinder = CinderView.new()
	_cinder.radius_px = 56.0
	add_child(_cinder)


func _make_mm(shape: String, radius_m: float) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = ShapeMeshes.build(shape, ShapeMeshes.stroke_for(STROKE_PX, radius_m * OLD_PX_PER_M))
	var inst := MultiMeshInstance2D.new()
	inst.multimesh = mm
	add_child(inst)
	return mm


## `layout_px` positions are new-look pixels (33.75 px/m with stand-off); convert back to meters, redraw old.
func set_formation(layout: StyleFrameLayout, boss_px: Array[Vector2], band: int) -> void:
	var counts: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	for t: int in layout.types:
		counts[t] += 1
	var fill: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
	for t: int in SHAPES.size():
		_mms[t].instance_count = counts[t]
	for i: int in layout.types.size():
		var t: int = layout.types[i]
		var p: Vector2 = _old_pos(layout.pos[i])
		_mms[t].set_instance_transform_2d(fill[t], _xf(p, RADII_M[t] * OLD_PX_PER_M))
		_mms[t].set_instance_color(fill[t], Color.WHITE)
		fill[t] += 1
	_boss_mm.instance_count = boss_px.size()
	for b: int in boss_px.size():
		_boss_mm.set_instance_transform_2d(b, _xf(_old_pos(boss_px[b]), 3.0 * OLD_PX_PER_M))
		_boss_mm.set_instance_color(b, Color.WHITE)
	_cinder.set_state(1.0, band, deg_to_rad(-35.0), 0.0)


func _process(delta: float) -> void:
	_time += delta
	_cinder.set_state(1.0, cinder_band, deg_to_rad(-35.0), _time)


static func _old_pos(new_px: Vector2) -> Vector2:
	var r_px: float = new_px.length()
	# invert StyleFrameLayout.draw_radius by bisection on meters
	var lo: float = 2.0
	var hi: float = 40.0
	for _i: int in 20:
		var mid: float = (lo + hi) * 0.5
		if StyleFrameLayout.draw_radius(mid) < r_px:
			lo = mid
		else:
			hi = mid
	return new_px.normalized() * lo * OLD_PX_PER_M if r_px > 0.01 else Vector2.ZERO


static func _xf(p: Vector2, scale_px: float) -> Transform2D:
	var a: float = (-p).angle()
	return Transform2D(Vector2(cos(a), sin(a)) * scale_px, Vector2(-sin(a), cos(a)) * scale_px, p)
