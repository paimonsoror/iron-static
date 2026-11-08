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
		assert_bool(inst.multimesh.use_custom_data).is_true()
		assert_bool(inst.multimesh.use_colors).is_true()
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
	var armor: float = 2.0 * 33.75 * 1.5
	assert_float(p.x - r.sprite_radius_px(2) - armor).is_equal_approx(ViewMath.CONTACT_GAP_PX, 0.01)
