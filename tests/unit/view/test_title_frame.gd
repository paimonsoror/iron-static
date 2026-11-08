extends GdUnitTestSuite
## M3-25 title style frame: tier smoke layers / embers and reduce motion (node-tree tests).


func _make() -> TitleFrameStage:
	var st := TitleFrameStage.new()
	add_child(st)
	st.build()
	st.layout(Vector2(1080.0, 2400.0))
	return auto_free(st)


func test_low_has_one_smoke_layer_and_no_embers() -> void:
	var st: TitleFrameStage = _make()
	st.set_tier(VisualQuality.Tier.LOW)
	assert_int(st.visible_smoke_count()).is_equal(1)
	st.tick(1.0, 2.0)
	assert_bool(st.embers_active()).is_false()
	assert_int(st.ember_count()).is_equal(0)
	st.set_tier(VisualQuality.Tier.HIGH)
	assert_int(st.visible_smoke_count()).is_equal(3)
	st.set_tier(VisualQuality.Tier.MID)
	assert_int(st.visible_smoke_count()).is_equal(2)


func test_reduce_motion_freezes_drift_embers_and_flare() -> void:
	var st: TitleFrameStage = _make()
	st.reduce_motion = true
	st.set_tier(VisualQuality.Tier.HIGH)
	st.tick(5.0, 1.0)
	var layer: Sprite2D = st.get_child(3) as Sprite2D
	var p1: Vector2 = layer.position
	st.tick(25.0, 20.0)
	assert_vector(layer.position).is_equal(p1)
	assert_bool(st.embers_active()).is_false()
	assert_int(st.ember_count()).is_equal(0)
	assert_bool(st.flare_active()).is_false()
