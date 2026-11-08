class_name TestCinderLayout
extends GdUnitTestSuite


func test_rig_scale_matches_armor_ring() -> void:
	# radius_px 100/0.92 gives the reference art (armor ring 100 px)
	assert_float(CinderLayout.rig_scale(100.0 / 0.92)).is_equal_approx(1.0, 0.0001)
	assert_float(CinderLayout.rig_scale(110.0) * 100.0).is_equal_approx(110.0 * 0.92, 0.0001)


func test_wedge_slots_alternate_a_b() -> void:
	assert_str(CinderLayout.wedge_slot(0, CinderWedges.INTACT)).is_equal("cinder_wedge_a_intact")
	assert_str(CinderLayout.wedge_slot(1, CinderWedges.INTACT)).is_equal("cinder_wedge_b_intact")
	assert_str(CinderLayout.wedge_slot(2, CinderWedges.CHARRED)).is_equal("cinder_wedge_a_charred")
	assert_str(CinderLayout.wedge_slot(7, CinderWedges.CHARRED)).is_equal("cinder_wedge_b_charred")
	assert_str(CinderLayout.wedge_slot(3, CinderWedges.GONE)).is_equal("")
	assert_str(CinderLayout.wedge_glow_slot(4, CinderWedges.INTACT)).is_equal("cinder_seam_glow")
	assert_str(CinderLayout.wedge_glow_slot(4, CinderWedges.CHARRED)).is_equal("cinder_ember_edge_a")
	assert_str(CinderLayout.wedge_glow_slot(5, CinderWedges.CHARRED)).is_equal("cinder_ember_edge_b")
	assert_str(CinderLayout.wedge_glow_slot(5, CinderWedges.GONE)).is_equal("")


func test_every_slot_used_exists_in_the_table() -> void:
	var ids: Array[String] = [
		CinderLayout.SLOT_SHADOW,
		CinderLayout.SLOT_FRAME,
		CinderLayout.SLOT_FRAME_HOT,
		CinderLayout.SLOT_RING,
		CinderLayout.SLOT_RING_GLOW,
		CinderLayout.SLOT_HOUSING,
		CinderLayout.SLOT_CORE,
		CinderLayout.SLOT_CORE_HOT,
		CinderLayout.SLOT_CRACK,
		CinderLayout.SLOT_HALO,
		CinderLayout.SLOT_HALO_HOT,
		CinderLayout.SLOT_CRACK_GLOW,
		CinderLayout.SLOT_VISOR,
		CinderLayout.SLOT_VISOR_GLOW,
		CinderLayout.SLOT_SHOULDER,
		CinderLayout.SLOT_SHOULDER_GLOW,
		CinderLayout.SLOT_TICKS,
		CinderLayout.SLOT_TICKS_GLOW,
		CinderLayout.SLOT_SEAM_GLOW
	]
	for state: int in [CinderWedges.INTACT, CinderWedges.CHARRED]:
		for k: int in 2:
			ids.append(CinderLayout.wedge_slot(k, state))
			ids.append(CinderLayout.wedge_glow_slot(k, state))
	for id: String in ids:
		assert_bool(ArtSlots.has(id)).is_true()


func test_band_to_core_and_extras() -> void:
	assert_str(CinderLayout.core_slot(0)).is_equal("cinder_core")
	assert_str(CinderLayout.core_slot(2)).is_equal("cinder_core")
	assert_str(CinderLayout.core_slot(3)).is_equal("cinder_core_hot")
	assert_str(CinderLayout.core_halo_slot(3)).is_equal("cinder_core_hot_halo")
	assert_bool(CinderLayout.has_crack(1)).is_false()
	assert_bool(CinderLayout.has_crack(2)).is_true()
	assert_bool(CinderLayout.has_frame_hot(2)).is_false()
	assert_bool(CinderLayout.has_frame_hot(3)).is_true()


func test_tier_toggles_glow() -> void:
	assert_float(CinderLayout.glow_factor(VisualQuality.high().glow_sheets)).is_equal(1.0)
	assert_float(CinderLayout.glow_factor(VisualQuality.mid().glow_sheets)).is_equal(1.0)
	assert_float(CinderLayout.glow_factor(VisualQuality.low().glow_sheets)).is_equal(0.0)


func test_wedge_rotation_steps_30_degrees() -> void:
	assert_float(CinderLayout.wedge_rotation(0)).is_equal(0.0)
	assert_float(CinderLayout.wedge_rotation(3)).is_equal_approx(deg_to_rad(90.0), 0.0001)


func test_ring_aligns_a_node_with_aim() -> void:
	for deg: int in range(-180, 180, 17):
		var aim: float = deg_to_rad(float(deg))
		for k: int in 3:
			var rot: float = CinderLayout.ring_rotation_for(aim, k)
			assert_int(CinderLayout.active_node(rot, aim)).is_equal(k)
			var dir: Vector2 = Vector2.from_angle(CinderLayout.node_angle(rot, k))
			assert_float(dir.angle_to(Vector2.from_angle(aim))).is_equal_approx(0.0, 0.0001)


func test_ring_target_turns_at_most_60_degrees() -> void:
	for deg: int in range(-180, 180, 7):
		var aim: float = deg_to_rad(float(deg))
		var cur: float = 0.3
		var tgt: float = CinderLayout.ring_target(cur, aim)
		assert_bool(absf(tgt - cur) <= deg_to_rad(60.0) + 0.0001).is_true()
		(
			assert_float(
				CinderLayout.node_position(tgt, CinderLayout.active_node(tgt, aim), 1.0).angle_to(
					Vector2.from_angle(aim)
				)
			)
			. is_equal_approx(0.0, 0.001)
		)


func test_node_position_radius_and_node_zero_up() -> void:
	var p: Vector2 = CinderLayout.node_position(0.0, 0, 1.0)
	assert_float(p.x).is_equal_approx(0.0, 0.001)
	assert_float(p.y).is_equal_approx(-102.0, 0.001)
	assert_float(CinderLayout.node_position(1.0, 2, 2.0).length()).is_equal_approx(204.0, 0.001)


func test_cell_draw_rect_puts_pivot_at_origin() -> void:
	var r: Rect2 = CinderLayout.cell_draw_rect(Vector2(64, 196), Vector2(128, 112), 0.5)
	assert_vector(r.position).is_equal(Vector2(-32, -98))
	assert_vector(r.size).is_equal(Vector2(64, 56))
