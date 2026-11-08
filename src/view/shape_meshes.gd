class_name ShapeMeshes
extends RefCounted
## Procedural vector silhouettes (GDD 03 section 1.5, GDD 07 section 5.1, TECH 2.6).
## Each mesh is one triangle surface: dark fill (Palette.ENEMY_FILL at alpha 0.8) plus the
## outline as constant-width quads. Unit sized (bounding radius 1.0), facing +x, per-vertex
## colors so a MultiMesh instance color can tint. Max 12 outline segments per shape.

const SHAPE_IDS: Array[String] = ["skitter", "dart", "walker", "lancer", "boss_hulk", "bolt"]
const MAX_SEGMENTS: int = 12
## Default stroke in unit space (about 3 px over a 0.5 m skitter at 28 px/m would be 0.21).
const DEFAULT_STROKE: float = 0.12
## Corner extent of a square-capped quad is about 0.71 * stroke; keep geometry inside radius 1.
const CORNER_REACH: float = 0.75


## Unit-space stroke width that renders as `stroke_px` for an instance scaled to `radius_px`.
static func stroke_for(stroke_px: float, radius_px: float) -> float:
	return stroke_px / maxf(radius_px, 0.001)


## Builds the mesh for `shape_id` (see SHAPE_IDS). `stroke` is the outline width in unit space.
static func build(shape_id: String, stroke: float = DEFAULT_STROKE) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var fill := PackedVector2Array()
	var segs := PackedVector2Array()
	if not _geometry(shape_id, fill, segs):
		push_error("ShapeMeshes: unknown shape '%s'" % shape_id)
		return mesh
	var scale_f: float = _fit_scale(fill, segs, stroke)
	var outline_color: Color = Palette.ENEMY_FIRE if shape_id == "bolt" else Palette.ENEMY_OUTLINE
	var fill_color: Color = Palette.ENEMY_FILL
	fill_color.a = Palette.ENEMY_FILL_ALPHA
	var verts := PackedVector2Array()
	var colors := PackedColorArray()
	for p: Vector2 in fill:
		verts.append(p * scale_f)
		colors.append(fill_color)
	var half: float = stroke * 0.5
	for i: int in range(0, segs.size(), 2):
		var a: Vector2 = segs[i] * scale_f
		var b: Vector2 = segs[i + 1] * scale_f
		var d: Vector2 = (b - a).normalized() * half
		var n: Vector2 = Vector2(-d.y, d.x)
		var a2: Vector2 = a - d
		var b2: Vector2 = b + d
		verts.append_array(PackedVector2Array([a2 + n, a2 - n, b2 - n, a2 + n, b2 - n, b2 + n]))
		for k: int in 6:
			colors.append(outline_color)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Number of outline segments of a shape (0 for unknown ids).
static func segment_count(shape_id: String) -> int:
	var fill := PackedVector2Array()
	var segs := PackedVector2Array()
	if not _geometry(shape_id, fill, segs):
		return 0
	return segs.size() >> 1


static func _fit_scale(fill: PackedVector2Array, segs: PackedVector2Array, stroke: float) -> float:
	var r2: float = 0.0
	for p: Vector2 in fill:
		r2 = maxf(r2, p.length_squared())
	for p: Vector2 in segs:
		r2 = maxf(r2, p.length_squared())
	var avail: float = maxf(1.0 - CORNER_REACH * stroke, 0.1)
	return avail / maxf(sqrt(r2), 0.001)


## Fills `fill` (triangle list) and `segs` (point pairs). Returns false for unknown ids.
static func _geometry(shape_id: String, fill: PackedVector2Array, segs: PackedVector2Array) -> bool:
	match shape_id:
		"skitter":
			var body: Array[Vector2] = [Vector2(0.75, 0.0), Vector2(-0.45, 0.4), Vector2(-0.45, -0.4)]
			_add_fan(fill, body)
			_add_loop(segs, body)
			for side: float in [1.0, -1.0]:
				for x: float in [0.3, -0.05, -0.4]:
					var edge_y: float = 0.4 * (0.75 - x) / 1.2
					segs.append(Vector2(x, side * edge_y))
					segs.append(Vector2(x - 0.3, side * 0.9))
		"dart":
			var tip := Vector2(1.0, 0.0)
			var top := Vector2(-0.55, 0.7)
			var notch := Vector2(-0.15, 0.0)
			var bottom := Vector2(-0.55, -0.7)
			fill.append_array(PackedVector2Array([tip, top, notch, tip, notch, bottom]))
			var chevron: Array[Vector2] = [tip, top, notch, bottom]
			_add_loop(segs, chevron)
			for y: float in [0.25, 0.0, -0.25]:
				segs.append(Vector2(-0.75, y))
				segs.append(Vector2(-1.05, y))
		"walker":
			var outer: Array[Vector2] = [Vector2(0.6, 0.5), Vector2(-0.7, 0.8), Vector2(-0.7, -0.8), Vector2(0.6, -0.5)]
			var inner: Array[Vector2] = []
			for p: Vector2 in outer:
				inner.append(p * 0.7)
			_add_fan(fill, outer)
			_add_loop(segs, outer)
			_add_loop(segs, inner)
			for side: float in [1.0, -1.0]:
				for x: float in [0.25, -0.35]:
					var edge_y: float = 0.5 + 0.3 * (0.6 - x) / 1.3
					segs.append(Vector2(x, side * edge_y))
					segs.append(Vector2(x, side * (edge_y + 0.3)))
		"lancer":
			var diamond: Array[Vector2] = [
				Vector2(0.6, 0.0), Vector2(0.0, 0.55), Vector2(-0.6, 0.0), Vector2(0.0, -0.55)
			]
			_add_fan(fill, diamond)
			_add_loop(segs, diamond)
			segs.append(Vector2(0.6, 0.0))
			segs.append(Vector2(1.3, 0.0))
		"boss_hulk":
			var hexa: Array[Vector2] = [
				Vector2(1.0, 0.0),
				Vector2(0.5, 0.85),
				Vector2(-0.5, 0.85),
				Vector2(-1.0, 0.0),
				Vector2(-0.5, -0.85),
				Vector2(0.5, -0.85)
			]
			_add_fan(fill, hexa)
			_add_loop(segs, hexa)
			for x: float in [-0.4, 0.0, 0.4]:
				segs.append(Vector2(x, 0.55))
				segs.append(Vector2(x, -0.55))
		"bolt":
			var bolt: Array[Vector2] = [Vector2(1.0, 0.0), Vector2(0.0, 0.55), Vector2(-1.0, 0.0), Vector2(0.0, -0.55)]
			_add_fan(fill, bolt)
			_add_loop(segs, bolt)
		_:
			return false
	return true


## Triangle fan around the origin for a convex polygon given in order.
static func _add_fan(fill: PackedVector2Array, poly: Array[Vector2]) -> void:
	for i: int in poly.size():
		fill.append(Vector2.ZERO)
		fill.append(poly[i])
		fill.append(poly[(i + 1) % poly.size()])


static func _add_loop(segs: PackedVector2Array, poly: Array[Vector2]) -> void:
	for i: int in poly.size():
		segs.append(poly[i])
		segs.append(poly[(i + 1) % poly.size()])
