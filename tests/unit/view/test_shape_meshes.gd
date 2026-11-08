class_name TestShapeMeshes
extends GdUnitTestSuite


func _vertices(mesh: ArrayMesh) -> PackedVector2Array:
	var arrays: Array = mesh.surface_get_arrays(0)
	var raw: Variant = arrays[Mesh.ARRAY_VERTEX]
	var out := PackedVector2Array()
	if raw is PackedVector2Array:
		out = raw
	elif raw is PackedVector3Array:
		var v3: PackedVector3Array = raw
		for p: Vector3 in v3:
			out.append(Vector2(p.x, p.y))
	return out


func test_every_shape_builds_a_valid_mesh() -> void:
	for id: String in ShapeMeshes.SHAPE_IDS:
		var mesh: ArrayMesh = ShapeMeshes.build(id)
		assert_int(mesh.get_surface_count()).is_greater_equal(1)
		var verts: PackedVector2Array = _vertices(mesh)
		assert_int(verts.size()).is_greater(0)
		assert_int(verts.size()).is_less(400)
		assert_int(verts.size() % 3).is_equal(0)


func test_segment_counts_within_budget() -> void:
	for id: String in ShapeMeshes.SHAPE_IDS:
		var n: int = ShapeMeshes.segment_count(id)
		assert_int(n).is_greater(0)
		assert_int(n).is_less_equal(ShapeMeshes.MAX_SEGMENTS)


func test_vertices_within_unit_radius() -> void:
	for id: String in ShapeMeshes.SHAPE_IDS:
		for stroke: float in [0.05, ShapeMeshes.DEFAULT_STROKE, 0.2]:
			var verts: PackedVector2Array = _vertices(ShapeMeshes.build(id, stroke))
			for p: Vector2 in verts:
				assert_float(p.length()).is_less_equal(1.05)


func test_colors_present_and_match_palette() -> void:
	var mesh: ArrayMesh = ShapeMeshes.build("skitter")
	var raw: Variant = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var colors: PackedColorArray = raw
	assert_int(colors.size()).is_equal(_vertices(mesh).size())
	assert_float(colors[0].a).is_equal_approx(0.8, 0.001)
	assert_bool(colors[colors.size() - 1].is_equal_approx(Palette.ENEMY_OUTLINE)).is_true()
	var bolt_raw: Variant = ShapeMeshes.build("bolt").surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var bolt_colors: PackedColorArray = bolt_raw
	assert_bool(bolt_colors[bolt_colors.size() - 1].is_equal_approx(Palette.ENEMY_FIRE)).is_true()


func test_stroke_for_converts_pixels_to_unit_space() -> void:
	assert_float(ShapeMeshes.stroke_for(3.0, 30.0)).is_equal_approx(0.1, 0.0001)
