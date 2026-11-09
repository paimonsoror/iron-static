class_name TestShaderWarmup
extends GdUnitTestSuite
## ShaderWarmup (V1-24): builds every material once, stays on screen with a non-zero alpha for FRAMES frames, then
## frees itself.


func test_builds_each_material_and_is_drawable() -> void:
	var w := ShaderWarmup.new()
	add_child(w)
	auto_free(w)
	var instanced: int = 0
	var shaders: Array[Shader] = []
	var rects: int = 0
	var layers: int = 0
	var logos: int = 0
	for child: Node in w.get_children():
		if child is MultiMeshInstance2D:
			instanced += 1
			var mm: MultiMesh = (child as MultiMeshInstance2D).multimesh
			assert_bool(mm.use_colors).is_false()  # V1-29: transform only, data in a texture
			assert_bool(mm.use_custom_data).is_false()
			shaders.append(((child as MultiMeshInstance2D).material as ShaderMaterial).shader)
		elif child is ColorRect:
			rects += 1
			shaders.append(((child as ColorRect).material as ShaderMaterial).shader)
		elif child is TitleLogo:
			logos += 1
			shaders.append(((child as TitleLogo).material as ShaderMaterial).shader)
		elif child is CinderLayer:
			layers += 1
			assert_object((child as CinderLayer).material).is_instanceof(CanvasItemMaterial)
	assert_int(instanced).is_equal(3)  # enemy, particle additive, particle smoke
	assert_int(rects).is_equal(3)  # arena fx and overlay, title smoke
	assert_int(logos).is_equal(1)  # title logo shimmer
	assert_int(layers).is_equal(1)
	assert_int(shaders.size()).is_equal(7)
	assert_bool(shaders.has(load(TitleArt.SHADER_SMOKE) as Shader)).is_true()
	assert_bool(shaders.has(load(TitleArt.SHADER_LOGO) as Shader)).is_true()
	assert_bool(shaders.has(ArenaBackground.FX_SHADER)).is_true()
	assert_bool(shaders.has(ArenaBackground.OVERLAY_SHADER)).is_true()
	assert_float(w.modulate.a).is_greater(0.0)  # a transparent draw is culled
	assert_bool(w.visible).is_true()
	assert_float(w.position.x).is_greater_equal(0.0)


func test_frees_itself_after_frames() -> void:
	var w := ShaderWarmup.new()
	add_child(w)
	for i: int in ShaderWarmup.FRAMES:
		w._process(0.016)
		assert_bool(w.is_queued_for_deletion()).is_false()
	w._process(0.016)
	assert_bool(w.is_queued_for_deletion()).is_true()
