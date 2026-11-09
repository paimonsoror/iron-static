class_name TestEnemyRenderer
extends GdUnitTestSuite
## Headless EnemyRenderer: textured MultiMeshes, allocation-free render, glow ramp, per-type stand-off.


func _renderer() -> EnemyRenderer:
	var r: EnemyRenderer = auto_free(EnemyRenderer.new())
	add_child(r)
	var radii := PackedFloat32Array([0.6, 0.5, 1.4, 0.7, 3.0])
	r.setup(33.75, radii, EnemyStore.DEFAULT_CAPACITY, ProjectileStore.DEFAULT_CAPACITY, 2.0)
	return r


func _fill(world: SimWorld, count: int) -> void:
	for k: int in count:
		var t: int = k % 5
		var i: int = world.enemies.alloc(t)
		if i < 0:
			return
		var p: Vector2 = Vector2.from_angle(float(k) * 0.37) * (3.0 + float(k % 40))
		world.enemies.pos_x[i] = p.x
		world.enemies.pos_y[i] = p.y
		world.enemies.prev_x[i] = p.x
		world.enemies.prev_y[i] = p.y
		world.enemies.radius[i] = 0.6


func test_render_500_enemies_is_allocation_free_after_warmup() -> void:
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	var r: EnemyRenderer = _renderer()
	_fill(world, 500)
	r.render(world, 1.0)
	r.render(world, 0.5)
	var before: int = r.resize_count
	for k: int in 20:
		world.events.push(SimEventKind.ENEMY_HIT, k, 5)
		r.render(world, float(k % 10) / 10.0)
	assert_int(r.resize_count).is_equal(before)
	var shown: int = 0
	for c: Node in r.get_children():
		var inst: MultiMeshInstance2D = c as MultiMeshInstance2D
		shown += inst.multimesh.visible_instance_count
		assert_bool(inst.multimesh.use_custom_data).is_false()  # V1-29: transform only
		assert_bool(inst.multimesh.use_colors).is_false()
	assert_int(shown).is_greater(0)
	assert_int(r.get_child_count()).is_equal(6)


func test_hit_event_flashes_the_instance() -> void:
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	var r: EnemyRenderer = _renderer()
	_fill(world, 5)
	r.render(world, 1.0)  # binds the cursor
	world.events.push(SimEventKind.ENEMY_HIT, 2, 5)
	r.render(world, 1.0)
	assert_float(r.flash_at(2)).is_greater(0.5)
	assert_float(r.flash_at(1)).is_equal(0.0)


func test_glow_follows_density_and_tier() -> void:
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	var r: EnemyRenderer = _renderer()
	r.visual = VisualSettings.new()
	_fill(world, 10)
	r.render(world, 1.0)
	assert_float(r.glow_strength()).is_equal(1.0)
	_fill(world, 165)
	r.render(world, 1.0)
	assert_float(r.glow_strength()).is_less(1.0)
	r.visual.quality = VisualQuality.low()
	r.render(world, 1.0)
	assert_float(r.glow_strength()).is_equal(0.0)


func test_contact_standoff_differs_per_type_and_draw_pos_uses_it() -> void:
	var r: EnemyRenderer = _renderer()
	assert_float(r.standoff_px(2)).is_greater(r.standoff_px(0))
	assert_float(r.standoff_px(4)).is_greater(r.standoff_px(2))
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	var i: int = world.enemies.alloc(2)
	world.enemies.pos_x[i] = 2.0
	world.enemies.prev_x[i] = 2.0
	var p: Vector2 = r.draw_pos(world.enemies, i, 1.0)
	var armor: float = 2.0 * 33.75 * 1.5 * ViewMath.CINDER_SCALE
	assert_float(p.x - r.sprite_radius_px(2) - armor).is_equal_approx(ViewMath.CONTACT_GAP_PX, 0.01)


func test_data_texture_carries_flash_frame_spawn_phase_per_instance() -> void:
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	var r: EnemyRenderer = _renderer()
	var slots: Array[int] = []
	for k: int in 3:
		var i: int = world.enemies.alloc(1)  # dart: type 1
		slots.append(i)
		world.enemies.pos_x[i] = 5.0 + float(k)
		world.enemies.prev_x[i] = 5.0 + float(k)
		world.enemies.radius[i] = 0.5
	r.render(world, 1.0)  # binds the fx state
	var fx: EnemyFxState = r._fx
	fx.flash[slots[1]] = 0.6
	fx.spawn_age[slots[2]] = 0.1  # spawn factor 0.5
	r._last_now_s = Time.get_ticks_msec() / 1000.0  # dt ~ 0
	r.render(world, 1.0)
	var data: PackedFloat32Array = r._data[1]
	var d: int = MultiMeshBuffer.DATA_FLOATS
	var order: Array[int] = slots.duplicate()
	order.sort()  # fill() walks the store in slot order; instance n = n-th alive slot
	var n1: int = order.find(slots[1])
	var n2: int = order.find(slots[2])
	assert_float(data[n1 * d + MultiMeshBuffer.D_FLASH]).is_equal_approx(0.6, 0.05)
	assert_float(data[(n1 + 1) % 3 * d + MultiMeshBuffer.D_FLASH]).is_equal(0.0)
	assert_float(data[n2 * d + MultiMeshBuffer.D_SPAWN]).is_between(0.4, 0.6)
	assert_float(data[(n2 + 1) % 3 * d + MultiMeshBuffer.D_SPAWN]).is_equal(1.0)
	for k: int in 3:
		assert_float(data[k * d + MultiMeshBuffer.D_PHASE]).is_equal_approx(
			EnemyInstanceData.pulse_seed(order[k]), 1e-5
		)
		var f: float = data[k * d + MultiMeshBuffer.D_FRAME]
		assert_float(f).is_equal(floorf(f))
		assert_float(f).is_between(0.0, 3.0)
	# the uploaded texture is a per-type RGBAH row sized to capacity, read by the shader as u_inst
	var tex: ImageTexture = r._data_tex[1]
	assert_int(tex.get_width()).is_equal(EnemyStore.DEFAULT_CAPACITY)
	assert_int(tex.get_height()).is_equal(1)
	assert_int(tex.get_format()).is_equal(Image.FORMAT_RGBAH)
	assert_object(r._mats[1].get_shader_parameter("u_inst")).is_same(tex)
