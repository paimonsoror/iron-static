class_name TestShakeModel
extends GdUnitTestSuite
## V1-14: trauma model, caps per setting and tier, trigger table, reduce motion, HUD stability.


func _trauma(kind: int, a: int, b: int) -> float:
	return ShakeModel.trauma_for_event(kind, a, b, 100.0)


func test_zero_trauma_gives_exactly_zero_offset() -> void:
	var m := ShakeModel.new()
	assert_vector(m.offset(1.234, 10.0)).is_equal(Vector2.ZERO)
	m.add_trauma(0.5)
	assert_vector(m.offset(1.234, 0.0)).is_equal(Vector2.ZERO)


func test_offset_never_exceeds_max_px() -> void:
	var m := ShakeModel.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k: int in 10000:
		m.trauma = rng.randf()
		var max_px: float = 5.0 if k % 2 == 0 else 10.0
		var o: Vector2 = m.offset(rng.randf() * 1000.0, max_px)
		assert_float(o.length()).is_less_equal(max_px + 0.0001)


func test_trauma_decays_below_001_within_2_5_s() -> void:
	var m := ShakeModel.new()
	m.add_trauma(5.0)
	assert_float(m.trauma).is_equal(1.0)
	for i: int in 150:
		m.decay(1.0 / 60.0)
	assert_float(m.trauma).is_less(0.01)


func test_damage_fraction_mapping() -> void:
	assert_float(ShakeModel.hit_trauma(0.05)).is_equal_approx(0.10, 1.0e-6)
	assert_float(ShakeModel.hit_trauma(0.5)).is_equal_approx(0.28, 1.0e-6)
	assert_float(ShakeModel.hit_trauma(1.0)).is_equal_approx(0.30, 1.0e-6)
	assert_float(_trauma(SimEventKind.CINDER_HIT, 5, 0)).is_equal_approx(0.10, 1.0e-6)


func test_event_table() -> void:
	assert_float(_trauma(SimEventKind.BAND_CHANGED, 0, 1)).is_equal(0.5)
	assert_float(_trauma(SimEventKind.BAND_CHANGED, 2, 3)).is_equal(0.65)
	assert_float(_trauma(SimEventKind.BAND_CHANGED, 2, 1)).is_equal(0.0)  # heal
	assert_float(_trauma(SimEventKind.BOSS_SPAWNED, 3, 0)).is_equal(0.35)
	assert_float(_trauma(SimEventKind.ENEMY_KILLED, 3, ShakeModel.BOSS_TYPE)).is_equal(0.7)
	assert_float(_trauma(SimEventKind.RUN_ENDED, 9, 0)).is_equal(0.9)


func test_kills_hits_and_own_beam_add_nothing() -> void:
	for type_index: int in 4:
		assert_float(_trauma(SimEventKind.ENEMY_KILLED, 1, type_index)).is_equal(0.0)
	var quiet: Array[int] = [
		SimEventKind.ENEMY_HIT, SimEventKind.SHOT_FIRED, SimEventKind.ENEMY_SPAWNED, SimEventKind.WAVE_STARTED
	]
	for kind: int in quiet:
		assert_float(_trauma(kind, 1, 1)).is_equal(0.0)


func test_caps_per_setting_tier_and_reduce_motion() -> void:
	var v := VisualSettings.new()
	v.set_tier(VisualQuality.Tier.HIGH)
	v.screen_shake = VisualSettings.Shake.NORMAL
	assert_float(v.effective_shake_px()).is_equal(10.0)
	v.set_tier(VisualQuality.Tier.MID)
	assert_float(v.effective_shake_px()).is_equal(5.0)
	v.set_tier(VisualQuality.Tier.HIGH)
	v.screen_shake = VisualSettings.Shake.LOW
	assert_float(v.effective_shake_px()).is_equal(5.0)
	v.screen_shake = VisualSettings.Shake.OFF
	assert_float(v.effective_shake_px()).is_equal(0.0)
	v.screen_shake = VisualSettings.Shake.NORMAL
	v.reduce_motion = true
	assert_float(v.effective_shake_px()).is_equal(0.0)


func test_impact_driver_shakes_and_respects_settings() -> void:
	var v := VisualSettings.new()
	v.screen_shake = VisualSettings.Shake.NORMAL
	var w := SimWorld.new(SimConfigLoader.load_default(1))
	var d := ImpactDriver.new()
	d.bind(w)
	w.events.push(SimEventKind.RUN_ENDED, 3, 0)
	var o: Vector2 = d.update(w, 1.0, v, 1, 1.0)
	assert_float(d.shake.trauma).is_equal(0.9)
	assert_float(o.length()).is_less_equal(10.0)
	# reduce motion: events add nothing and the offset is zero
	var d2 := ImpactDriver.new()
	d2.bind(w)
	v.reduce_motion = true
	w.events.push(SimEventKind.RUN_ENDED, 3, 0)
	assert_vector(d2.update(w, 1.0, v, 1, 1.0)).is_equal(Vector2.ZERO)
	assert_float(d2.shake.trauma).is_equal(0.0)


func test_impact_driver_ignores_kills_and_triggers_boss_slowmo() -> void:
	var v := VisualSettings.new()
	var w := SimWorld.new(SimConfigLoader.load_default(1))
	var d := ImpactDriver.new()
	d.bind(w)
	w.events.push(SimEventKind.ENEMY_KILLED, 1, 0)
	w.events.push(SimEventKind.ENEMY_HIT, 1, 5)
	w.events.push(SimEventKind.SHOT_FIRED, 1, 0)
	assert_vector(d.update(w, 1.0, v, 1, 1.0)).is_equal(Vector2.ZERO)
	assert_float(d.time_scale).is_equal(1.0)
	w.events.push(SimEventKind.ENEMY_KILLED, 1, ShakeModel.BOSS_TYPE)
	@warning_ignore("return_value_discarded")
	d.update(w, 1.016, v, 1, 1.0)
	assert_float(d.time_scale).is_less(1.0)
	assert_float(d.shake.trauma).is_greater(0.0)


func test_hud_positions_unchanged_by_shake() -> void:
	var hud: Control = auto_free(Control.new())
	hud.position = Vector2(0.0, 40.0)
	var scene: PackedScene = load("res://src/view/battle_view.tscn")
	var view: BattleView = auto_free(scene.instantiate())
	add_child(hud)
	add_child(view)
	view.layout(Vector2(1080.0, 1920.0))
	var base: Vector2 = view.position
	var before: Vector2 = hud.global_position
	view.apply_shake(Vector2(4.0, -3.0))
	assert_vector(view.position).is_equal(base + Vector2(4.0, -3.0))
	assert_vector(hud.global_position).is_equal(before)
	view.apply_shake(Vector2.ZERO)
	assert_vector(view.position).is_equal(base)
