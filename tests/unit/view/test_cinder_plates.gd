class_name TestCinderPlates
extends GdUnitTestSuite
## VT-3 armor plates: tier lookup from the hull level, cell layout, slot rows of the three frames and the plates
## layer of `CinderView` (hidden at MK I, changes only when the level crosses a tier, behind the integrity ring).

const FRAMES: Array[String] = ["vanguard", "bulwark", "striker"]
const SLOTS: Array[String] = [
	CinderPlates.SLOT_CORNER,
	CinderPlates.SLOT_BRIDGE,
	CinderPlates.SLOT_LIP,
	CinderPlates.SLOT_CAP,
	CinderPlates.SLOT_CORNER_TRIM,
	CinderPlates.SLOT_BRIDGE_TRIM,
	CinderPlates.SLOT_LIP_DIODE,
	CinderPlates.SLOT_CAP_TRIM,
]


func _hull_row(world: SimWorld) -> int:
	for i: int in world.config.upgrades.size():
		if world.config.upgrades[i].id == CinderPlates.UPGRADE_ID:
			return i
	return -1


func _bound_view(world: SimWorld) -> CinderView:
	var view: CinderView = auto_free(CinderView.new())
	add_child(view)
	view.bind_world(world)
	return view


func test_tier_for_level_follows_the_hull_thresholds() -> void:
	var model: VisualTierModel = VisualTierModel.shared()
	assert_int(CinderPlates.tier_for_level(model, 0)).is_equal(0)
	assert_int(CinderPlates.tier_for_level(model, 4)).is_equal(0)
	assert_int(CinderPlates.tier_for_level(model, 5)).is_equal(1)
	assert_int(CinderPlates.tier_for_level(model, 11)).is_equal(1)
	assert_int(CinderPlates.tier_for_level(model, 12)).is_equal(2)
	assert_int(CinderPlates.tier_for_level(model, 24)).is_equal(2)
	assert_int(CinderPlates.tier_for_level(model, 25)).is_equal(3)
	assert_int(CinderPlates.tier_for_level(model, 400)).is_equal(3)


func test_layout_counts_and_angles() -> void:
	assert_int(CinderPlates.quad_count(0)).is_equal(0)
	assert_int(CinderPlates.quad_count(1)).is_equal(4)
	assert_int(CinderPlates.quad_count(2)).is_equal(8)
	assert_int(CinderPlates.quad_count(3)).is_equal(28)
	assert_float(CinderPlates.corner_angle(0)).is_equal_approx(deg_to_rad(45.0), 0.0001)
	assert_float(CinderPlates.corner_angle(3)).is_equal_approx(deg_to_rad(315.0), 0.0001)
	assert_float(CinderPlates.bridge_angle(1)).is_equal_approx(deg_to_rad(90.0), 0.0001)
	assert_float(CinderPlates.lip_angle(0)).is_equal_approx(deg_to_rad(11.25), 0.0001)
	var diodes: int = 0
	for k: int in CinderPlates.LIP_COUNT:
		if CinderPlates.lip_has_diode(k):
			diodes += 1
	assert_int(diodes).is_equal(8)


func test_every_frame_has_the_plate_slots_inside_their_sheets() -> void:
	for id: String in FRAMES:
		var spec: CinderFrameSpec = CinderFrameSpec.for_frame(id)
		for base: String in SLOTS:
			var sid: String = spec.slot(base)
			assert_bool(ArtSlots.has(sid)).override_failure_message("missing slot " + sid).is_true()
			var art: ArtSlot = ArtSlots.slot(sid)
			var r: Rect2i = Rect2i(art.frame_rect(0))
			assert_bool(Rect2i(0, 0, art.sheet_size.x, art.sheet_size.y).encloses(r)).is_true()
			assert_bool(art.additive).is_equal(base.ends_with("trim") or base.ends_with("diode"))


func test_plates_start_hidden_and_mk1_draws_none() -> void:
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	var view: CinderView = _bound_view(world)
	view.set_state(1.0, 0, 0.0, 1.0)
	assert_int(view.plate_tier()).is_equal(0)
	var layer: CinderLayer = view.get_child(0) as CinderLayer
	assert_bool(layer.show_behind_parent).is_true()
	assert_bool(layer.visible).is_false()


func test_plate_tier_follows_the_run_level_and_changes_only_at_tiers() -> void:
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	var row: int = _hull_row(world)
	assert_int(row).is_greater_equal(0)
	var view: CinderView = _bound_view(world)
	var layer: CinderLayer = view.get_child(0) as CinderLayer
	var levels: Array[int] = [0, 4, 5, 11, 12, 24, 25, 60]
	var tiers: Array[int] = [0, 0, 1, 1, 2, 2, 3, 3]
	for i: int in levels.size():
		world.run_levels[row] = levels[i]
		view.set_state(1.0, 0, 0.0, 1.0)
		assert_int(view.plate_tier()).is_equal(tiers[i])
		assert_bool(layer.visible).is_equal(tiers[i] > 0)
	world.run_levels[row] = 0
	view.set_state(1.0, 0, 0.0, 2.0)
	assert_int(view.plate_tier()).is_equal(0)


func test_plates_ignore_the_skin_burn_band() -> void:
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	world.run_levels[_hull_row(world)] = 25
	var view: CinderView = _bound_view(world)
	for band: int in 4:
		view.set_state(1.0, band, 0.0, 1.0 + float(band))
		assert_int(view.plate_tier()).is_equal(3)


func test_rebinding_to_a_new_run_resets_the_plates() -> void:
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	world.run_levels[_hull_row(world)] = 12
	var view: CinderView = _bound_view(world)
	assert_int(view.plate_tier()).is_equal(2)
	view.bind_world(SimWorld.new(SimConfigLoader.load_default(2)))
	assert_int(view.plate_tier()).is_equal(0)
	view.bind_world(null)
	view.set_state(1.0, 0, 0.0, 3.0)
	assert_int(view.plate_tier()).is_equal(0)
