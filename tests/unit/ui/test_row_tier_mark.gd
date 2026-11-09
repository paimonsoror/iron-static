class_name TestRowTierMark
extends GdUnitTestSuite
## VT-6: the mark chip, the NEXT LOOK AT line and the progress bar of an UpgradeRow, from UpgradeRowModel tier fields.


func _world() -> SimWorld:
	return SimWorld.new(SimConfigLoader.load_default(1))


func _row_index(w: SimWorld, id: String) -> int:
	for i: int in w.config.upgrades.size():
		if w.config.upgrades[i].id == id:
			return i
	return -1


func _model(w: SimWorld, id: String, level: int) -> UpgradeRowModel:
	var i: int = _row_index(w, id)
	w.run_levels[i] = level
	var p: UpgradePreview = UpgradeSystem.preview(w, i, 1)
	return UpgradeRowModel.from_preview(p, p.affordable, p.level, w.config.upgrades[i])


func _row() -> UpgradeRow:
	var packed: PackedScene = load("res://src/ui/upgrade_row.tscn")
	var row: UpgradeRow = auto_free(packed.instantiate())
	add_child(row)
	return row


func test_model_fields_for_tiered_and_plain_rows() -> void:
	var w: SimWorld = _world()
	var m: UpgradeRowModel = _model(w, "laser_output", 8)
	assert_bool(m.tier_has).is_true()
	assert_int(m.tier).is_equal(2)
	assert_str(m.mark_text).is_equal("MK II")
	assert_str(m.next_text).is_equal("NEXT LOOK AT L12")
	assert_float(m.tier_progress).is_equal_approx(3.0 / 7.0, 0.0001)
	assert_bool(m.tier_top).is_false()
	var plain: UpgradeRowModel = _model(w, "cycle_rate", 8)
	assert_bool(plain.tier_has).is_false()
	assert_str(plain.mark_text).is_empty()
	assert_str(plain.next_text).is_empty()


func test_row_shows_chip_line_and_bar_for_a_tiered_row() -> void:
	var w: SimWorld = _world()
	var row: UpgradeRow = _row()
	row.apply(_model(w, "laser_output", 8))
	assert_bool((row.get_node("%TierLine") as Control).visible).is_true()
	assert_str((row.get_node("%MarkLabel") as Label).text).is_equal("MK II")
	assert_str((row.get_node("%NextLabel") as Label).text).is_equal("NEXT LOOK AT L12")
	var bar: ProgressBar = row.get_node("%TierBar")
	assert_bool(bar.visible).is_true()
	assert_float(bar.value).is_equal_approx(3.0 / 7.0, 0.001)
	assert_bool(row.tier_mark().is_chip_visible()).is_true()


func test_mk1_is_shown_dim_and_mk2_lit() -> void:
	var w: SimWorld = _world()
	var row: UpgradeRow = _row()
	var chip: Label = row.get_node("%MarkLabel")
	row.apply(_model(w, "laser_output", 0))
	assert_str(chip.text).is_equal("MK I")
	assert_str((row.get_node("%NextLabel") as Label).text).is_equal("NEXT LOOK AT L5")
	assert_that(chip.get_theme_color("font_color")).is_equal(Palette.TEXT_DIM)
	row.apply(_model(w, "laser_output", 5))
	assert_str(chip.text).is_equal("MK II")
	assert_that(chip.get_theme_color("font_color")).is_equal(Palette.AMBER)


func test_top_mark_hides_the_bar_and_says_top_mark() -> void:
	var w: SimWorld = _world()
	var row: UpgradeRow = _row()
	row.apply(_model(w, "laser_output", 24))
	assert_bool((row.get_node("%TierBar") as Control).visible).is_true()
	row.apply(_model(w, "laser_output", 25))
	assert_str((row.get_node("%MarkLabel") as Label).text).is_equal("MK IV")
	assert_str((row.get_node("%NextLabel") as Label).text).is_equal("TOP MARK")
	assert_bool((row.get_node("%TierBar") as Control).visible).is_false()
	assert_bool(row.tier_mark().is_bar_visible()).is_false()


func test_plating_below_first_mark_hides_the_chip_but_keeps_the_line() -> void:
	var w: SimWorld = _world()
	var row: UpgradeRow = _row()
	row.apply(_model(w, "plating_pct", 1))
	assert_bool((row.get_node("%MarkLabel") as Control).visible).is_false()
	assert_str((row.get_node("%NextLabel") as Label).text).is_equal("NEXT LOOK AT L3")
	row.apply(_model(w, "plating_pct", 3))
	assert_str((row.get_node("%MarkLabel") as Label).text).is_equal("PLATED I")
	assert_bool((row.get_node("%MarkLabel") as Control).visible).is_true()


func test_rows_without_tiers_are_unchanged() -> void:
	var w: SimWorld = _world()
	var row: UpgradeRow = _row()
	row.apply(_model(w, "cycle_rate", 8))
	assert_bool((row.get_node("%TierLine") as Control).visible).is_false()
	assert_bool((row.get_node("%TierBar") as Control).visible).is_false()
	assert_bool(row.tier_mark().is_chip_visible()).is_false()


func test_reapplying_an_unchanged_model_rewrites_nothing_and_touch_target_is_kept() -> void:
	var w: SimWorld = _world()
	var row: UpgradeRow = _row()
	row.apply(_model(w, "laser_output", 12))
	var next: Label = row.get_node("%NextLabel")
	var before: String = next.text
	row.apply(_model(w, "laser_output", 12))
	assert_str(next.text).is_equal(before)
	assert_str(next.text).is_equal("NEXT LOOK AT L25")
	assert_float((row.get_node("%BuyButton") as Button).custom_minimum_size.y).is_equal(148.0)
	assert_int((row.get_node("%NextLabel") as Label).get_theme_font_size("font_size")).is_greater_equal(38)


func test_mk4_lands_on_the_x25_ring_without_overlapping_it() -> void:
	var w: SimWorld = _world()
	var m24: UpgradeRowModel = _model(w, "laser_output", 24)
	assert_bool(m24.milestone_glow).is_true()
	assert_int(m24.tier).is_equal(3)
	var m25: UpgradeRowModel = _model(w, "laser_output", 25)
	assert_bool(m25.milestone_glow).is_false()
	assert_int(m25.tier).is_equal(4)
