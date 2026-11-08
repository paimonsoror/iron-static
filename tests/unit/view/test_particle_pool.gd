class_name TestParticlePool
extends GdUnitTestSuite
## Ring logic of the particle pool (V1-13): capacity, oldest-first reuse, tier caps, packing, sweep.


func _emit(pool: ParticlePool, birth: float = 1.0, life: float = 0.5) -> int:
	return pool.emit(Vector2(12.5, -40.0), Vector2(100.0, -50.0), birth, life, Vector2(20.0, 8.0), Color.WHITE, 8)


func test_write_never_exceeds_capacity_and_overwrites_oldest_first() -> void:
	var pool := ParticlePool.new()
	pool.setup(400)
	for i: int in 450:
		var slot: int = _emit(pool)
		assert_int(pool.id_at(slot)).is_equal(i)
	assert_int(pool.used).is_equal(400)
	assert_int(pool.buffer.size()).is_equal(400 * ParticlePack.FLOATS)
	assert_int(pool.data.size()).is_equal(400 * ParticlePack.DATA_FLOATS)
	var present := {}
	for s: int in 400:
		present[pool.id_at(s)] = true
	for i: int in 50:
		assert_bool(present.has(i)).is_false()
	for i: int in range(50, 450):
		assert_bool(present.has(i)).is_true()
	# the next write replaces the oldest survivor (id 50, slot 50)
	assert_int(_emit(pool)).is_equal(50)


func test_empty_slots_are_dead_and_counts_follow_time() -> void:
	var pool := ParticlePool.new()
	pool.setup(10)
	assert_bool(pool.is_dead_slot(3)).is_true()
	assert_int(pool.live_count(0.0)).is_equal(0)
	for i: int in 4:
		_emit(pool, 1.0, 0.5)
	assert_int(pool.live_count(1.2)).is_equal(4)
	assert_int(pool.live_count(1.6)).is_equal(0)


func test_emit_does_not_allocate_after_setup() -> void:
	var pool := ParticlePool.new()
	pool.setup(64)
	var size_before: int = pool.buffer.size()
	for i: int in 1000:
		_emit(pool, float(i) * 0.01)
	assert_int(pool.buffer.size()).is_equal(size_before)
	assert_int(pool.total_written).is_equal(1000)
	assert_int(pool.head).is_equal(1000 % 64)


func test_fields_roundtrip() -> void:
	var pool := ParticlePool.new()
	pool.setup(4)
	var c := Color(1.0, 0.5, 0.0, 0.8)
	var slot: int = pool.emit(Vector2(100.25, -7.5), Vector2(-300.0, 420.0), 5.0, 0.75, Vector2(30.0, 12.0), c, 13)
	var o: int = slot * ParticlePack.FLOATS
	var d: int = slot * ParticlePack.DATA_FLOATS
	assert_float(pool.buffer[o + 3]).is_equal(100.25)
	assert_float(pool.buffer[o + 7]).is_equal(-7.5)
	assert_float(pool.data[d + ParticlePack.D_LIFE]).is_equal_approx(0.75, 0.001)
	assert_float(pool.data[d + ParticlePack.D_A]).is_equal_approx(0.8, 0.0001)
	assert_int(pool.kind_at(slot)).is_equal(13)
	assert_float(pool.data[d + ParticlePack.D_R]).is_equal_approx(1.0, 0.0001)
	assert_float(pool.data[d + ParticlePack.D_G]).is_equal_approx(0.5, 0.0001)
	assert_float(pool.data[d + ParticlePack.D_B]).is_equal_approx(0.0, 0.0001)
	assert_float(pool.data[d + ParticlePack.D_VX]).is_equal(-300.0)
	assert_float(pool.data[d + ParticlePack.D_VY]).is_equal(420.0)
	assert_float(pool.data[d + ParticlePack.D_S0]).is_equal(30.0)
	assert_float(pool.data[d + ParticlePack.D_S1]).is_equal(12.0)
	assert_int(pool.birth_units_at(slot)).is_equal(320)  # 5.0 s * 64


func test_emit_matches_the_pack_helpers() -> void:
	var pool := ParticlePool.new()
	pool.setup(2)
	var slot: int = pool.emit(Vector2.ZERO, Vector2(77.0, -12.0), 3.3, 0.31, Vector2(14.0, 9.0), Color.WHITE, 5)
	var d: int = slot * ParticlePack.DATA_FLOATS
	assert_float(pool.data[d + ParticlePack.D_BIRTH]).is_equal(ParticlePack.clock_birth(3.3))
	assert_float(pool.data[d + ParticlePack.D_LIFE]).is_equal(ParticlePack.life_seconds(0.31))


func test_bad_input_is_clamped_to_legitimate_ranges() -> void:
	var pool := ParticlePool.new()
	pool.setup(2)
	var slot: int = pool.emit(
		Vector2(5000.0, 5000.0),
		Vector2(9999.0, -9999.0),
		9999.0,
		99.0,
		Vector2(9999.0, -5.0),
		Color(7.0, -1.0, 2.0, 9.0),
		99
	)
	var d: int = slot * ParticlePack.DATA_FLOATS
	for k: int in [ParticlePack.D_R, ParticlePack.D_G, ParticlePack.D_B, ParticlePack.D_A]:
		assert_bool(pool.data[d + k] >= 0.0 and pool.data[d + k] <= 1.0).is_true()
	assert_float(pool.data[d + ParticlePack.D_VX]).is_equal(ParticlePack.VEL_MAX)
	assert_float(pool.data[d + ParticlePack.D_VY]).is_equal(-ParticlePack.VEL_MAX)
	assert_float(pool.data[d + ParticlePack.D_S0]).is_equal(ParticlePack.SIZE_MAX)
	assert_float(pool.data[d + ParticlePack.D_S1]).is_equal(0.0)
	assert_float(pool.data[d + ParticlePack.D_LIFE]).is_equal(ParticlePack.LIFE_MAX_S)
	assert_int(pool.kind_at(slot)).is_equal(31)
	assert_float(pool.data[d + ParticlePack.D_BIRTH]).is_less(ParticlePack.CLOCK_PERIOD_S)


func test_sweep_marks_expired_slots_dead_but_keeps_live_ones() -> void:
	var pool := ParticlePool.new()
	pool.setup(8)
	var old: int = _emit(pool, 1.0, 0.5)
	var young: int = _emit(pool, 9.0, 0.5)
	assert_int(pool.sweep(9.2)).is_equal(1)
	assert_bool(pool.is_dead_slot(old)).is_true()
	assert_bool(pool.is_dead_slot(young)).is_false()
	assert_int(pool.sweep(9.2)).is_equal(0)


func test_clock_wraps_every_32_seconds() -> void:
	assert_int(ParticlePack.clock_units(0.0)).is_equal(0)
	assert_int(ParticlePack.clock_units(32.0)).is_equal(0)
	assert_int(ParticlePack.clock_units(33.5)).is_equal(96)
	assert_float(ParticlePack.clock_now(65.0)).is_equal_approx(1.0, 0.0001)


func test_tier_caps_size_the_renderer_pools() -> void:
	for tier: VisualQuality.Tier in [VisualQuality.Tier.HIGH, VisualQuality.Tier.MID, VisualQuality.Tier.LOW]:
		var cap: int = VisualQuality.for_tier(tier).particle_cap
		var r: ParticleRenderer = auto_free(ParticleRenderer.new())
		add_child(r)
		r.setup(cap)
		assert_int(r.capacity_total()).is_equal(cap)
		assert_int(r.smoke.capacity).is_greater(0)
		assert_int(r.get_child_count()).is_equal(2)  # additive + alpha smoke = 2 draw calls
	assert_int(VisualQuality.high().particle_cap).is_equal(400)
	assert_int(VisualQuality.mid().particle_cap).is_equal(200)
	assert_int(VisualQuality.low().particle_cap).is_equal(80)
