class_name TestMultiMeshBuffer
extends GdUnitTestSuite

const F: int = MultiMeshBuffer.FLOATS_PER_INSTANCE
const D: int = MultiMeshBuffer.DATA_FLOATS


func _out(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	assert_int(out.resize(n * F)).is_equal(OK)
	return out


func _dat(n: int) -> PackedFloat32Array:
	var data := PackedFloat32Array()
	assert_int(data.resize(n * D)).is_equal(OK)
	return data


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
	var dat := _dat(1)
	MultiMeshBuffer.write_instance(out, dat, 0, 12.0, -7.0, 0.7, 3.0)
	var xf := Transform2D(0.7, Vector2(12.0, -7.0)).scaled_local(Vector2(3.0, 3.0))
	var ref: Array[float] = [xf.x.x, xf.y.x, 0.0, xf.origin.x, xf.x.y, xf.y.y, 0.0, xf.origin.y]
	for k: int in F:
		assert_float(out[k]).is_equal_approx(ref[k], 0.0001)


func test_known_enemy_transform_and_origin() -> void:
	var store := EnemyStore.new(8)
	assert_int(_spawn(store, 2, 10.0, 0.0, 10.0, 0.0)).is_greater_equal(0)
	var out := _out(8)
	var dat := _dat(8)
	var n: int = MultiMeshBuffer.fill(store, 2, 1.0, 20.0, out, dat)
	assert_int(n).is_equal(1)
	# Enemy on +x faces the origin: angle pi, scale 0.5 m * 20 = 10 px.
	assert_float(out[0]).is_equal_approx(-10.0, 0.001)  # basis.x.x
	assert_float(out[1]).is_equal_approx(0.0, 0.001)  # basis.y.x
	assert_float(out[3]).is_equal_approx(200.0, 0.001)  # origin.x
	assert_float(out[4]).is_equal_approx(0.0, 0.001)  # basis.x.y
	assert_float(out[5]).is_equal_approx(-10.0, 0.001)  # basis.y.y
	assert_float(out[7]).is_equal_approx(0.0, 0.001)  # origin.y
	assert_float(dat[3]).is_equal(0.0)  # no spec: phase 0


func test_interpolation_at_alpha_0_half_1() -> void:
	var store := EnemyStore.new(8)
	assert_int(_spawn(store, 0, 10.0, 4.0, 6.0, 4.0)).is_greater_equal(0)
	var out := _out(8)
	var dat := _dat(8)
	var expect: Array[float] = [60.0, 80.0, 100.0]
	var alphas: Array[float] = [0.0, 0.5, 1.0]
	for k: int in 3:
		assert_int(MultiMeshBuffer.fill(store, 0, alphas[k], 10.0, out, dat)).is_equal(1)
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
	var dat := _dat(16)
	assert_int(MultiMeshBuffer.fill(store, 0, 1.0, 10.0, out, dat)).is_equal(3)
	assert_int(MultiMeshBuffer.fill(store, 4, 1.0, 10.0, out, dat)).is_equal(0)
	assert_int(MultiMeshBuffer.fill(store, 1, 1.0, 10.0, out, dat)).is_equal(3)
	assert_float(out[3]).is_equal_approx(50.0, 0.001)
	assert_float(out[F + 3]).is_equal_approx(70.0, 0.001)
	assert_float(out[2 * F + 3]).is_equal_approx(90.0, 0.001)


func test_fill_is_bounded_by_output_capacity() -> void:
	var store := EnemyStore.new(8)
	for i: int in 4:
		assert_int(_spawn(store, 0, 5.0, float(i), 5.0, float(i))).is_greater_equal(0)
	assert_int(MultiMeshBuffer.fill(store, 0, 1.0, 10.0, _out(2), _dat(2))).is_equal(2)


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
	var dat := _dat(8)
	var dt: float = 1.0 / 30.0
	assert_int(MultiMeshBuffer.fill_bolts(store, 1.0, dt, 10.0, 0.3, out, dat)).is_equal(1)
	assert_float(out[7]).is_equal_approx(0.0, 0.001)
	assert_int(MultiMeshBuffer.fill_bolts(store, 0.0, dt, 10.0, 0.3, out, dat)).is_greater_equal(0)
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
	var dat := _dat(8)
	var ppm: float = 33.75
	assert_int(MultiMeshBuffer.fill(store, 0, 1.0, ppm, out, dat, 1.5, true)).is_equal(2)
	assert_float(out[3]).is_equal_approx(2.0 * ppm + 72.0, 0.001)
	assert_float(out[0]).is_equal_approx(-0.5 * ppm * 1.5, 0.001)  # faces origin, scaled
	assert_float(out[F + 7]).is_equal_approx(40.0 * ppm, 0.001)
	var cull := Rect2(-600.0, -700.0, 1200.0, 1400.0)
	assert_int(MultiMeshBuffer.fill(store, 0, 1.0, ppm, out, dat, 1.5, true, cull)).is_equal(1)
	assert_float(out[3]).is_equal_approx(2.0 * ppm + 72.0, 0.001)


func test_data_texel_holds_flash_frame_spawn_phase() -> void:
	var out := _out(2)
	var dat := _dat(2)
	MultiMeshBuffer.write_instance(out, dat, 1, 5.0, 6.0, 0.3, 2.0, 0.25, 3.0, 0.5, 1.37)
	assert_int(MultiMeshBuffer.FLOATS_PER_INSTANCE).is_equal(8)  # transform only: no colour, no custom data
	assert_int(MultiMeshBuffer.DATA_FLOATS).is_equal(4)
	assert_float(dat[D + MultiMeshBuffer.D_FLASH]).is_equal_approx(0.25, 1e-6)
	assert_float(dat[D + MultiMeshBuffer.D_FRAME]).is_equal_approx(3.0, 1e-6)
	assert_float(dat[D + MultiMeshBuffer.D_SPAWN]).is_equal_approx(0.5, 1e-6)
	assert_float(dat[D + MultiMeshBuffer.D_PHASE]).is_equal_approx(1.37, 1e-6)
	assert_float(out[F + 3]).is_equal_approx(5.0, 1e-6)
	assert_float(dat[0]).is_equal(0.0)  # instance 0 untouched


func test_buffer_matches_a_real_transform_only_multimesh() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = false
	mm.use_custom_data = false
	mm.instance_count = 2
	var xf := Transform2D(0.7, Vector2(12.0, -7.0)).scaled_local(Vector2(3.0, 3.0))
	mm.set_instance_transform_2d(1, xf)
	var real: PackedFloat32Array = mm.buffer
	if real.is_empty():
		return  # headless dummy renderer keeps no buffer; the layout is verified by the desktop capture
	assert_int(real.size()).is_equal(2 * F)
	var out := _out(2)
	var dat := _dat(2)
	MultiMeshBuffer.write_instance(out, dat, 1, 12.0, -7.0, 0.7, 3.0)
	for k: int in F:
		assert_float(out[F + k]).is_equal_approx(real[F + k], 0.0001)


func test_data_image_is_one_row_rgbah_one_texel_per_instance() -> void:
	var dat := _dat(5)
	var out := _out(5)
	MultiMeshBuffer.write_instance(out, dat, 3, 0.0, 0.0, 0.0, 1.0, 0.25, 2.0, 0.5, 9.75)
	var img: Image = MultiMeshBuffer.data_image(dat)
	assert_int(img.get_format()).is_equal(Image.FORMAT_RGBAH)
	assert_int(img.get_width()).is_equal(5)
	assert_int(img.get_height()).is_equal(1)
	var c: Color = img.get_pixel(3, 0)  # texel x = instance index
	assert_float(c.r).is_equal(0.25)
	assert_float(c.g).is_equal(2.0)
	assert_float(c.b).is_equal(0.5)
	assert_float(c.a).is_equal(9.75)  # exact in a half (multiple of 1/64 below 16)
	# the largest phase seed (slot 511 * 0.137 = 70.0) stays within a half step (1/16 at 64..128)
	dat[3 * MultiMeshBuffer.DATA_FLOATS + MultiMeshBuffer.D_PHASE] = EnemyInstanceData.pulse_seed(511)
	assert_float(MultiMeshBuffer.data_image(dat).get_pixel(3, 0).a).is_equal_approx(
		EnemyInstanceData.pulse_seed(511), 0.04
	)
	assert_float(img.get_pixel(2, 0).g).is_equal(0.0)


func test_data_capacity_is_clamped_to_one_row() -> void:
	assert_int(MultiMeshBuffer.data_capacity(512)).is_equal(512)
	assert_int(MultiMeshBuffer.data_capacity(0)).is_equal(1)
	assert_int(MultiMeshBuffer.MAX_TEX_WIDTH).is_greater_equal(EnemyStore.DEFAULT_CAPACITY)
	assert_int(MultiMeshBuffer.MAX_TEX_WIDTH).is_greater_equal(ProjectileStore.DEFAULT_CAPACITY)


func test_textured_fill_writes_flash_frame_spawn_and_phase() -> void:
	var store := EnemyStore.new(8)
	var a: int = _spawn(store, 0, 10.0, 0.0, 10.0, 0.0)
	var b: int = _spawn(store, 0, 0.0, 10.0, 0.0, 10.0)
	var fx := EnemyFxState.new()
	fx.bind(SimEvents.new(), 8)
	fx.flash[b] = 0.5
	fx.spawn_age[b] = 0.1
	var spec := EnemyDrawSpec.new()
	spec.scale_px = 1.0
	spec.frames = 4
	spec.fps = 8.0
	spec.time_s = 1.0
	spec.fx = fx
	var out := _out(8)
	var dat := _dat(8)
	assert_int(MultiMeshBuffer.fill(store, 0, 1.0, 20.0, out, dat, 1.0, true, Rect2(), spec)).is_equal(2)
	var pa: float = EnemyInstanceData.phase_for(a, 4)
	var pb: float = EnemyInstanceData.phase_for(b, 4)
	assert_float(dat[1]).is_equal(float(EnemyInstanceData.frame_for(1.0, 8.0, pa, 4)))
	assert_float(dat[D + 1]).is_equal(float(EnemyInstanceData.frame_for(1.0, 8.0, pb, 4)))
	assert_float(dat[0]).is_equal(0.0)
	assert_float(dat[D]).is_equal_approx(0.5, 1e-6)
	assert_float(dat[2]).is_equal(1.0)
	assert_float(dat[D + 2]).is_equal_approx(0.5, 1e-6)
	assert_float(dat[3]).is_equal_approx(EnemyInstanceData.pulse_seed(a), 1e-5)
	assert_float(dat[D + 3]).is_equal_approx(EnemyInstanceData.pulse_seed(b), 1e-5)
	assert_float(out[0]).is_equal_approx(-1.0, 1e-5)  # unit scale, facing the origin


func test_textured_fill_uses_the_per_type_standoff() -> void:
	var store := EnemyStore.new(8)
	assert_int(_spawn(store, 2, 2.0, 0.0, 2.0, 0.0)).is_greater_equal(0)
	var spec := EnemyDrawSpec.new()
	spec.scale_px = 1.0
	spec.standoff_px = 100.0
	var out := _out(8)
	var dat := _dat(8)
	assert_int(MultiMeshBuffer.fill(store, 2, 1.0, 33.75, out, dat, 1.0, true, Rect2(), spec)).is_equal(1)
	assert_float(out[3]).is_equal_approx(2.0 * 33.75 + 100.0, 0.001)


func test_lancer_frame_follows_the_shot_clock() -> void:
	var store := EnemyStore.new(8)
	var i: int = _spawn(store, 3, 16.0, 0.0, 16.0, 0.0)
	store.next_attack_tick[i] = 100 + 60  # fired at tick 100
	var spec := EnemyDrawSpec.new()
	spec.scale_px = 1.0
	spec.frames = 3
	spec.fire_gap_ticks = 60
	var out := _out(8)
	var dat := _dat(8)
	var expect: Dictionary = {100.0: 2.0, 102.0: 2.0, 104.0: 1.0, 108.0: 1.0, 120.0: 0.0, 99.0: 0.0}
	for tick_f: float in expect:
		spec.tick_f = tick_f
		assert_int(MultiMeshBuffer.fill(store, 3, 1.0, 33.75, out, dat, 1.0, false, Rect2(), spec)).is_equal(1)
		assert_float(dat[1]).is_equal(expect[tick_f])
