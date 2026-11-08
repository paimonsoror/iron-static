class_name TestCinderFrameVariants
extends GdUnitTestSuite
## M3-27: the Bulwark and Striker rig variants mirror the VANGUARD rig slot for slot (same cells and pivots, other
## sheets), the frame id selects them, and VANGUARD keeps its unprefixed ids and constants.

const VARIANTS: Array[String] = ["bulwark", "striker"]


func _base_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for sid: String in ArtSlots.ids_of_family("cinder"):
		var art: ArtSlot = ArtSlots.slot(sid)
		if art.file == "cinder.svg" or art.file == "cinder_glow.svg":
			out.append(sid)
	return out


func test_vanguard_spec_is_the_unprefixed_rig() -> void:
	var s: CinderFrameSpec = CinderFrameSpec.for_frame("vanguard")
	assert_str(s.prefix).is_equal("")
	assert_str(s.slot(CinderLayout.SLOT_FRAME)).is_equal("cinder_frame")
	assert_vector(s.shoulder_pos).is_equal(CinderLayout.SHOULDER_POS)
	assert_vector(s.ticks_pos).is_equal(CinderLayout.TICKS_POS)
	assert_float(s.ticks_scale).is_equal(CinderLayout.TICKS_SCALE)
	assert_float(s.shadow_scale).is_equal(CinderLayout.SHADOW_SCALE)
	assert_float(s.node_radius_texels).is_equal(CinderLayout.NODE_RADIUS_TEXELS)
	assert_object(CinderFrameSpec.for_frame("")).is_same(s)
	assert_object(CinderFrameSpec.for_frame("salvager")).is_same(s)


func test_variant_slot_ids_are_prefixed() -> void:
	var b: CinderFrameSpec = CinderFrameSpec.for_frame("bulwark")
	assert_str(b.slot("cinder_frame")).is_equal("cinder_bulwark_frame")
	assert_str(b.slot("cinder_wedge_a_intact")).is_equal("cinder_bulwark_wedge_a_intact")
	assert_str(b.slot("cinder_ember_edge_b")).is_equal("cinder_bulwark_ember_edge_b")
	assert_str(b.slot("")).is_equal("")
	assert_str(CinderFrameSpec.for_frame("striker").slot("cinder_core")).is_equal("cinder_striker_core")


func test_every_vanguard_slot_has_a_matching_variant_slot() -> void:
	var ids: PackedStringArray = _base_ids()
	assert_int(ids.size()).is_greater_equal(25)
	for v: String in VARIANTS:
		var spec: CinderFrameSpec = CinderFrameSpec.for_frame(v)
		for sid: String in ids:
			var base: ArtSlot = ArtSlots.slot(sid)
			var var_art: ArtSlot = ArtSlots.slot(spec.slot(sid))
			assert_bool(var_art.valid).is_true()
			assert_str(var_art.file).is_equal(base.file.replace("cinder", "cinder_" + v))
			assert_vector(Vector2(var_art.cell_pos)).is_equal(Vector2(base.cell_pos))
			assert_vector(Vector2(var_art.cell_size)).is_equal(Vector2(base.cell_size))
			assert_vector(var_art.pivot).is_equal(base.pivot)
			assert_bool(var_art.additive).is_equal(base.additive)
			assert_str(var_art.glow_slot).is_equal(spec.slot(base.glow_slot) if not base.glow_slot.is_empty() else "")


func test_variant_sheets_load_at_the_rig_size() -> void:
	for v: String in VARIANTS:
		var spec: CinderFrameSpec = CinderFrameSpec.for_frame(v)
		var body: Texture2D = ArtSlots.texture(spec.slot(CinderLayout.SLOT_FRAME))
		var glow: Texture2D = ArtSlots.texture(spec.slot(CinderLayout.SLOT_FRAME_HOT))
		assert_vector(Vector2(body.get_size())).is_equal(Vector2(1024.0, 1024.0))
		assert_vector(Vector2(glow.get_size())).is_equal(Vector2(512.0, 512.0))


func test_every_wedge_state_resolves_for_every_frame() -> void:
	for fid: String in ["vanguard", "bulwark", "striker"]:
		var spec: CinderFrameSpec = CinderFrameSpec.for_frame(fid)
		for k: int in CinderWedges.WEDGE_COUNT:
			for state: int in [CinderWedges.INTACT, CinderWedges.CHARRED]:
				assert_bool(ArtSlots.slot(spec.slot(CinderLayout.wedge_slot(k, state))).valid).is_true()
				assert_bool(ArtSlots.slot(spec.slot(CinderLayout.wedge_glow_slot(k, state))).valid).is_true()


func test_selecting_a_frame_keeps_band_logic_and_emitters() -> void:
	var views: Array[CinderView] = []
	for fid: String in ["vanguard", "bulwark", "striker"]:
		var view: CinderView = auto_free(CinderView.new())
		add_child(view)
		view.radius_px = 110.0
		view.set_frame(fid)
		assert_str(view.frame_id()).is_equal(fid)
		view.set_state(1.0, 0, -PI * 0.5, 10.0)
		views.append(view)
	for i: int in 3:
		for k: int in 3:
			assert_vector(views[i].emitter_node_position(k)).is_equal_approx(
				views[0].emitter_node_position(k), Vector2(0.001, 0.001)
			)
		assert_vector(views[i].emitter_position()).is_equal_approx(views[0].emitter_position(), Vector2(0.001, 0.001))
		for band: int in 4:
			views[i].set_state(1.0, band, -PI * 0.5, 11.0 + float(band))
			assert_array(Array(views[i].rig().states)).is_equal(Array(CinderWedges.states(band)))


func test_set_frame_unknown_falls_back_to_vanguard() -> void:
	var view: CinderView = auto_free(CinderView.new())
	view.set_frame("bulwark")
	view.set_frame("nonsense")
	assert_str(view.frame_id()).is_equal("vanguard")


func test_battle_view_bind_selects_the_config_frame() -> void:
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	world.config.frame_id = "striker"
	var scene: PackedScene = load("res://src/view/battle_view.tscn")
	var view: BattleView = auto_free(scene.instantiate())
	add_child(view)
	view.layout(Vector2(1080.0, 2400.0))
	view.bind(world)
	assert_str(view.cinder_view().frame_id()).is_equal("striker")
	for i: int in 30:
		world.step()
		view.render(0.5)
