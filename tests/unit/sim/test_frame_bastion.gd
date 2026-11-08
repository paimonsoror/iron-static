class_name TestFrameBastion
extends GdUnitTestSuite
## Bastion: no single hit deals more than 20% of max hull (M3-22).


func _world(hull_foundry: int = 0) -> SimWorld:
	var m: FrameMods = FrameMods.new()
	m.passive = FrameMods.PASSIVE_BASTION
	var cfg: SimConfig = TestFrameMods.cfg_with("bulwark", m)
	cfg.debug_invulnerable = false
	if hull_foundry > 0:
		var lv: PackedInt32Array = PackedInt32Array()
		var ff: PackedFloat64Array = PackedFloat64Array()
		if lv.resize(cfg.upgrades.size()) != OK or ff.resize(cfg.upgrades.size()) != OK:
			push_error("resize failed")
		lv.fill(0)
		ff.fill(0.0)
		for i: int in cfg.upgrades.size():
			if cfg.upgrades[i].id == "hull_integrity":
				lv[i] = hull_foundry
				ff[i] = 0.06
		cfg.foundry_levels = lv
		cfg.foundry_f = ff
	var w: SimWorld = SimWorld.new(cfg)
	w.stats.plating_flat = 0.0
	w.stats.plating_pct = 0.0
	return w


func test_big_hit_is_capped_small_hit_is_not() -> void:
	var w: SimWorld = _world()
	assert_float(w.cinder.max_hp).is_equal_approx(100.0, 1.0e-9)
	var taken: float = w.cinder.apply_hit(90.0, w.stats, w.config.tuning)
	assert_float(taken).is_equal_approx(20.0, 1.0e-9)
	assert_float(w.cinder.hp).is_equal_approx(80.0, 1.0e-9)
	var small: float = w.cinder.apply_hit(10.0, w.stats, w.config.tuning)
	assert_float(small).is_equal_approx(10.0, 1.0e-9)


func test_cap_uses_the_larger_max_hull_with_foundry() -> void:
	var w: SimWorld = _world(10)
	var hull: float = w.cinder.max_hp
	assert_float(hull).is_greater(100.0)
	var taken: float = w.cinder.apply_hit(1.0e6, w.stats, w.config.tuning)
	assert_float(taken).is_equal_approx(0.20 * hull, 1.0e-9)


func test_melee_and_bolt_hits_both_go_through_the_cap() -> void:
	var w: SimWorld = _world()
	# Melee path: hit_cinder is the shared entry used by EnemyAttackSystem.
	EnemyAttackSystem.hit_cinder(w, 500.0, 0)
	assert_float(w.cinder.hp).is_equal_approx(80.0, 1.0e-9)
	# Bolt path: a bolt spawned on Cinder resolves in ProjectileSystem.
	var j: int = w.debug_spawn_bolt(0.0, 0.0, 0.0, 0.0, 500.0)
	assert_int(j).is_greater_equal(0)
	ProjectileSystem.step(w)
	assert_float(w.cinder.hp).is_equal_approx(60.0, 1.0e-6)


func test_without_bastion_the_hit_is_not_capped() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(3)
	var w: SimWorld = SimWorld.new(cfg)
	var taken: float = w.cinder.apply_hit(90.0, w.stats, w.config.tuning)
	assert_float(taken).is_greater(20.0)
