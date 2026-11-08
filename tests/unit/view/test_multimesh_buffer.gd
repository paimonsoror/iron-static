class_name TestMultiMeshBuffer
extends GdUnitTestSuite

const F: int = MultiMeshBuffer.FLOATS_PER_INSTANCE


func _out(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	assert_int(out.resize(n * F)).is_equal(OK)
	return out


func _spawn(store: EnemyStore, type: int, px: float, py: float, prx: float, pry: float) -> int:
	var i: int = store.alloc(type)
	store.pos_x[i] = px
	store.pos_y[i] = py
	store.prev_x[i] = prx
	store.prev_y[i] = pry
	store.radius[i] = 0.5
	return i


func test_layout_matches_godot_transform2d_buffer_order() -> void:
	# Godot source (mesh_storage.cpp, _multimesh_instance_set_transform_2d) and the
	# RenderingServer.multimesh_set_buffer docs: [c0.x, c1.x, 0, c2.x, c0.y, c1.y, 0, c2.y, rgba].
	var out := _out(1)
	MultiMeshBuffer.write_instance(out, 0, 12.0, -7.0, 0.7, 3.0)
	var xf := Transform2D(0.7, Vector2(12.0, -7.0)).scaled_local(Vector2(3.0, 3.0))
	var ref: Array[float] = [xf.x.x, xf.y.x, 0.0, xf.origin.x, xf.x.y, xf.y.y, 0.0, xf.origin.y, 1.0, 1.0, 1.0, 1.0]
	for k: int in F:
		assert_float(out[k]).is_equal_approx(ref[k], 0.0001)


func test_known_enemy_transform_and_origin() -> void:
	var store := EnemyStore.new(8)
	assert_int(_spawn(store, 2, 10.0, 0.0, 10.0, 0.0)).is_greater_equal(0)
	var out := _out(8)
	var n: int = MultiMeshBuffer.fill(store, 2, 1.0, 20.0, out)
	assert_int(n).is_equal(1)
	# Enemy on +x faces the origin: angle pi, scale 0.5 m * 20 = 10 px.
	assert_float(out[0]).is_equal_approx(-10.0, 0.001)  # basis.x.x
	assert_float(out[1]).is_equal_approx(0.0, 0.001)  # basis.y.x
	assert_float(out[3]).is_equal_approx(200.0, 0.001)  # origin.x
	assert_float(out[4]).is_equal_approx(0.0, 0.001)  # basis.x.y
	assert_float(out[5]).is_equal_approx(-10.0, 0.001)  # basis.y.y
	assert_float(out[7]).is_equal_approx(0.0, 0.001)  # origin.y
	for k: int in 4:
		assert_float(out[8 + k]).is_equal(1.0)


func test_interpolation_at_alpha_0_half_1() -> void:
	var store := EnemyStore.new(8)
	assert_int(_spawn(store, 0, 10.0, 4.0, 6.0, 4.0)).is_greater_equal(0)
	var out := _out(8)
	var expect: Array[float] = [60.0, 80.0, 100.0]
	var alphas: Array[float] = [0.0, 0.5, 1.0]
	for k: int in 3:
		assert_int(MultiMeshBuffer.fill(store, 0, alphas[k], 10.0, out)).is_equal(1)
		assert_float(out[3]).is_equal_approx(expect[k], 0.001)
		assert_float(out[7]).is_equal_approx(40.0, 0.001)


func test_count_matches_alive_of_type_and_skips_dead() -> void:
	var store := EnemyStore.new(16)
	var ids: Array[int] = []
	for i: int in 5:
		ids.append(_spawn(store, 1, 5.0 + i, 0.0, 5.0 + i, 0.0))
	for i: int in 3:
		assert_int(_spawn(store, 0, 3.0, 3.0 + i, 3.0, 3.0 + i)).is_greater_equal(0)
	store.release(ids[1])
	store.release(ids[3])
	var out := _out(16)
	assert_int(MultiMeshBuffer.fill(store, 0, 1.0, 10.0, out)).is_equal(3)
	assert_int(MultiMeshBuffer.fill(store, 4, 1.0, 10.0, out)).is_equal(0)
	assert_int(MultiMeshBuffer.fill(store, 1, 1.0, 10.0, out)).is_equal(3)
	assert_float(out[3]).is_equal_approx(50.0, 0.001)
	assert_float(out[F + 3]).is_equal_approx(70.0, 0.001)
	assert_float(out[2 * F + 3]).is_equal_approx(90.0, 0.001)


func test_fill_is_bounded_by_output_capacity() -> void:
	var store := EnemyStore.new(8)
	for i: int in 4:
		assert_int(_spawn(store, 0, 5.0, float(i), 5.0, float(i))).is_greater_equal(0)
	assert_int(MultiMeshBuffer.fill(store, 0, 1.0, 10.0, _out(2))).is_equal(2)


func test_bolts_interpolate_back_along_velocity() -> void:
	var store := ProjectileStore.new(8)
	var i: int = store.alloc()
	store.pos_x[i] = 10.0
	store.pos_y[i] = 0.0
	store.vel_x[i] = 0.0
	store.vel_y[i] = 30.0
	var dead: int = store.alloc()
	store.release(dead)
	var out := _out(8)
	var dt: float = 1.0 / 30.0
	assert_int(MultiMeshBuffer.fill_bolts(store, 1.0, dt, 10.0, 0.3, out)).is_equal(1)
	assert_float(out[7]).is_equal_approx(0.0, 0.001)
	assert_int(MultiMeshBuffer.fill_bolts(store, 0.0, dt, 10.0, 0.3, out)).is_greater_equal(0)
	assert_float(out[7]).is_equal_approx(-10.0, 0.001)  # one tick back: 30 m/s * dt = 1 m
	assert_float(out[3]).is_equal_approx(100.0, 0.001)
	assert_float(out[5]).is_equal_approx(0.0, 0.001)  # facing +y
	assert_float(out[4]).is_equal_approx(3.0, 0.001)


func test_fill_with_standoff_scale_and_cull() -> void:
	var store := EnemyStore.new(8)
	var near: int = _spawn(store, 0, 2.0, 0.0, 2.0, 0.0)
	assert_int(near).is_greater_equal(0)
	assert_int(_spawn(store, 0, 0.0, 40.0, 0.0, 40.0)).is_greater_equal(0)
	var out := _out(8)
	var ppm: float = 33.75
	assert_int(MultiMeshBuffer.fill(store, 0, 1.0, ppm, out, 1.5, true)).is_equal(2)
	assert_float(out[3]).is_equal_approx(2.0 * ppm + 72.0, 0.001)
	assert_float(out[0]).is_equal_approx(-0.5 * ppm * 1.5, 0.001)  # faces origin, scaled
	assert_float(out[F + 7]).is_equal_approx(40.0 * ppm, 0.001)
	var cull := Rect2(-600.0, -700.0, 1200.0, 1400.0)
	assert_int(MultiMeshBuffer.fill(store, 0, 1.0, ppm, out, 1.5, true, cull)).is_equal(1)
	assert_float(out[3]).is_equal_approx(2.0 * ppm + 72.0, 0.001)
