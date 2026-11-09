class_name TestDamageNumberLayer
extends GdUnitTestSuite
## DamageNumberLayer (M4-21): fed from real sim events, constant pool, reduce motion math, tier cap.


func _make_view(world: SimWorld) -> BattleView:
	var view: BattleView = auto_free((load("res://src/view/battle_view.tscn") as PackedScene).instantiate())
	add_child(view)
	view.layout(Vector2(1080.0, 1920.0))
	view.bind(world)
	return view


func test_layer_receives_events_and_draws_headless() -> void:
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	var view: BattleView = _make_view(world)
	var layer: DamageNumberLayer = view.get_node("DamageNumbers")
	var seen: int = 0
	for i: int in 900:
		world.step()
		if i % 3 == 0:
			view.render(0.5)
			seen = maxi(seen, layer.model.live_count())
	assert_int(layer.model.shown_total).is_greater(0)
	assert_int(seen).is_between(1, DamageNumberModel.POOL)


func test_pool_does_not_grow_after_1000_spawns() -> void:
	var layer: DamageNumberLayer = auto_free(DamageNumberLayer.new())
	add_child(layer)
	var m: DamageNumberModel = layer.model
	var t: float = 1.0
	for i: int in 1000:
		t += 0.01
		m.advance(t)
		m.hit(i, float(i % 50), 0.0, 90.0, 1000.0, i % 3 == 0)
		m.cinder_hit(5.0)
		assert_int(m.live_count()).is_less_equal(DamageNumberModel.POOL)
	assert_int(layer.get_child_count()).is_equal(0)
	layer.queue_redraw()


func test_reduce_motion_math() -> void:
	assert_float(DamageNumberLayer.punch_scale(0.0)).is_less(1.0)
	assert_float(DamageNumberLayer.punch_scale(0.03)).is_greater(1.0)
	assert_float(DamageNumberLayer.punch_scale(0.1)).is_equal(1.0)
	assert_float(DamageNumberLayer.rise_px(0.8, true, 1.0)).is_equal(0.0)
	assert_float(DamageNumberLayer.rise_px(1.0, false, 1.0)).is_equal(30.0)
	assert_float(DamageNumberLayer.ease_out(0.0)).is_equal(0.0)
	assert_float(DamageNumberLayer.ease_out(1.0)).is_equal(1.0)


func test_low_tier_caps_live_numbers_at_12() -> void:
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	var view: BattleView = _make_view(world)
	var layer: DamageNumberLayer = view.get_node("DamageNumbers")
	var settings := VisualSettings.new()
	settings.quality = VisualQuality.low()
	layer.visual = settings
	view.render(0.5)
	assert_int(layer.model.live_cap).is_equal(12)


func test_cinder_damage_gets_the_heavy_outline() -> void:
	# M4-27 F6: red Cinder numbers sit on the bright hit flash.
	assert_int(DamageNumberLayer.outline_px(DamageNumberModel.Kind.CINDER)).is_greater(
		DamageNumberLayer.outline_px(DamageNumberModel.Kind.NORMAL)
	)
	assert_int(DamageNumberLayer.outline_px(DamageNumberModel.Kind.NORMAL)).is_greater(0)
