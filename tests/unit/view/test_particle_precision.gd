class_name TestParticlePrecision
extends GdUnitTestSuite
## V1-26: the particle data path must survive low-precision mobile GPUs. The CPU side is checked by simulating fp16
## quantization of every stored field (worst case: a driver that holds the data as halves), the shader side by text.

const SHADER_PATH: String = "res://assets/shaders/particle_ring.gdshader"


## Rounds to the nearest IEEE half float (11-bit significand, subnormals below 2^-14).
static func half(v: float) -> float:
	if v == 0.0:
		return 0.0
	var e: int = clampi(floori(log(absf(v)) / log(2.0)), -14, 15)
	var quantum: float = pow(2.0, float(e - 10))
	return roundf(v / quantum) * quantum


func _record(pool: ParticlePool, slot: int) -> PackedFloat32Array:
	var d: int = slot * ParticlePack.DATA_FLOATS
	return pool.data.slice(d, d + ParticlePack.DATA_FLOATS)


func test_half_helper_matches_known_values() -> void:
	assert_float(half(1.0)).is_equal(1.0)
	assert_float(half(2047.0)).is_equal(2047.0)
	assert_float(half(2050.9)).is_equal(2050.0)  # 12 bits needed: an odd integer above 2048 is not exact
	assert_float(half(0.1)).is_equal_approx(0.0999755859375, 1.0e-9)
	assert_float(half(-1500.3)).is_equal(-1500.0)


func test_every_kind_survives_fp16_and_float32() -> void:
	var pool := ParticlePool.new()
	pool.setup(64)
	for kind: int in 32:
		var slot: int = pool.emit(
			Vector2(10.0, 20.0), Vector2(100.0, -50.0), 3.0, 0.5, Vector2(20.0, 8.0), Color.WHITE, kind
		)
		var rec: PackedFloat32Array = _record(pool, slot)
		assert_int(roundi(rec[ParticlePack.D_KIND])).is_equal(kind)
		assert_int(floori(half(rec[ParticlePack.D_KIND]) + 0.5)).is_equal(kind)
		assert_int(pool.kind_at(slot)).is_equal(kind)


func test_tint_and_alpha_across_the_full_range() -> void:
	var pool := ParticlePool.new()
	pool.setup(4)
	for i: int in 101:
		var v: float = float(i) / 100.0
		var slot: int = pool.emit(Vector2.ZERO, Vector2.ZERO, 1.0, 0.5, Vector2.ONE, Color(v, 1.0 - v, v * 0.5, v), 1)
		var rec: PackedFloat32Array = _record(pool, slot)
		var want: Array[float] = [v, 1.0 - v, v * 0.5, v]
		for k: int in 4:
			assert_float(rec[ParticlePack.D_R + k]).is_equal_approx(want[k], 1.0e-6)
			assert_float(half(rec[ParticlePack.D_R + k])).is_equal_approx(want[k], 0.0005)


func test_pale_impact_colours_keep_their_blue() -> void:
	# the field bug: CORE_AMBER and hot white lost blue. They must decode (fp16 worst case) within 1/255 per channel.
	for c: Color in [Color("FFE3A3"), Color(1.0, 0.98, 0.9), Color.WHITE]:
		var pool := ParticlePool.new()
		pool.setup(2)
		var rec: PackedFloat32Array = _record(pool, pool.emit(Vector2.ZERO, Vector2.ZERO, 0.0, 0.3, Vector2.ONE, c, 1))
		assert_float(half(rec[ParticlePack.D_R])).is_equal_approx(c.r, 1.0 / 255.0)
		assert_float(half(rec[ParticlePack.D_G])).is_equal_approx(c.g, 1.0 / 255.0)
		assert_float(half(rec[ParticlePack.D_B])).is_equal_approx(c.b, 1.0 / 255.0)


func test_velocity_across_the_full_range() -> void:
	var pool := ParticlePool.new()
	pool.setup(4)
	var v: float = -ParticlePack.VEL_MAX
	while v <= ParticlePack.VEL_MAX:
		var slot: int = pool.emit(Vector2.ZERO, Vector2(v, -v), 1.0, 0.5, Vector2.ONE, Color.WHITE, 8)
		var rec: PackedFloat32Array = _record(pool, slot)
		assert_float(rec[ParticlePack.D_VX]).is_equal(v)
		assert_float(half(rec[ParticlePack.D_VX])).is_equal_approx(v, 0.51)
		assert_float(half(rec[ParticlePack.D_VY])).is_equal_approx(-v, 0.51)
		v += 7.0


func test_size_across_the_full_range() -> void:
	var pool := ParticlePool.new()
	pool.setup(4)
	var s: float = 0.0
	while s <= ParticlePack.SIZE_MAX:
		var slot: int = pool.emit(
			Vector2.ZERO, Vector2.ZERO, 1.0, 0.5, Vector2(s, ParticlePack.SIZE_MAX - s), Color.WHITE, 1
		)
		var rec: PackedFloat32Array = _record(pool, slot)
		assert_float(rec[ParticlePack.D_S0]).is_equal_approx(s, 0.001)
		assert_float(half(rec[ParticlePack.D_S0])).is_equal_approx(s, 0.51)
		assert_float(half(rec[ParticlePack.D_S1])).is_equal_approx(ParticlePack.SIZE_MAX - s, 0.51)
		s += 3.7


func test_birth_and_life_across_the_full_range() -> void:
	var pool := ParticlePool.new()
	pool.setup(4)
	for i: int in 2048:
		var t: float = float(i) / 64.0 + 0.004
		var slot: int = pool.emit(Vector2.ZERO, Vector2.ZERO, t, 0.5, Vector2.ONE, Color.WHITE, 1)
		var rec: PackedFloat32Array = _record(pool, slot)
		assert_float(rec[ParticlePack.D_BIRTH]).is_equal(float(i) / 64.0)  # float32: exact multiples of 1/64
		assert_float(half(rec[ParticlePack.D_BIRTH])).is_equal_approx(float(i) / 64.0, 1.0 / 64.0)
	for u: int in range(1, 128):
		var life: float = float(u) / 64.0
		var slot: int = pool.emit(Vector2.ZERO, Vector2.ZERO, 1.0, life, Vector2.ONE, Color.WHITE, 1)
		var rec: PackedFloat32Array = _record(pool, slot)
		assert_float(rec[ParticlePack.D_LIFE]).is_equal(life)
		assert_float(half(rec[ParticlePack.D_LIFE])).is_equal_approx(life, 0.002)


func test_shader_has_no_bit_unpacking_and_reads_no_instance_color() -> void:
	var code: String = _shader_code()
	for banned: String in [
		"& 127", "& 31", "& 15", ">>", "<<", "/ 32.0", "/ 64.0", "/ 31.0", "/ 15.0", "INSTANCE_CUSTOM"
	]:
		assert_bool(code.contains(banned)).is_false()
	assert_bool(code.contains("COLOR.r") or code.contains("COLOR.g") or code.contains("COLOR.b")).is_false()
	assert_bool(code.contains("COLOR = clamp(")).is_true()  # the only COLOR use is the fragment output
	assert_bool(code.contains("floor(d_time.z + 0.5)")).is_true()  # kind: small integer, rounded decode


func test_shader_declares_highp_and_safety_clamps() -> void:
	var code: String = _shader_code()
	for needed: String in [
		"uniform highp sampler2D u_data",
		"uniform highp float u_now",
		"varying highp vec2 v_uv",
		"varying highp vec4 v_col",
		"const highp float SIZE_CAP",
		"highp vec4 d_col",
		"highp float size = clamp(",
		"highp vec3 rgb = clamp(",
		"highp float alpha = clamp(",
		"highp vec2 vel = clamp(",
	]:
		assert_bool(code.contains(needed)).override_failure_message("missing: " + needed).is_true()


func test_shader_caps_match_the_pack_constants() -> void:
	var code: String = _shader_code()
	assert_bool(code.contains("SIZE_CAP = %.1f;" % ParticlePack.SIZE_MAX)).is_true()
	assert_bool(code.contains("VEL_CAP = %.1f;" % ParticlePack.VEL_MAX)).is_true()
	assert_bool(code.contains("INSTANCE_ID * %d" % ParticlePack.TEXELS)).is_true()


func test_mix_variant_factory_replaces_only_the_blend_mode() -> void:
	var mix: Shader = ParticleRenderer.make_mix_shader()
	assert_bool(mix.code.contains("render_mode blend_mix;")).is_true()
	assert_bool(mix.code.contains("render_mode blend_add;")).is_false()
	assert_str(mix.code.replace("render_mode blend_mix;", "render_mode blend_add;")).is_equal(_shader_code())


func test_data_image_is_half_rgba_three_texels_per_particle() -> void:
	var pool := ParticlePool.new()
	pool.setup(5)
	pool.emit(Vector2.ZERO, Vector2(1.0, 2.0), 1.0, 0.5, Vector2(3.0, 4.0), Color(0.25, 0.5, 0.75, 1.0), 9)
	var img: Image = ParticleRenderer.data_image(pool)
	assert_int(img.get_width()).is_equal(5 * ParticlePack.TEXELS)
	assert_int(img.get_height()).is_equal(1)
	assert_int(img.get_format()).is_equal(Image.FORMAT_RGBAH)
	assert_float(img.get_pixel(0, 0).b).is_equal(0.75)
	assert_float(img.get_pixel(1, 0).a).is_equal(4.0)
	assert_float(img.get_pixel(2, 0).b).is_equal(9.0)


func _shader_code() -> String:
	return (load(SHADER_PATH) as Shader).code
