class_name TestRowTierTeal
extends GdUnitTestSuite
## VT-5: the next-look line of an upgrade row is teal for 3 s after the displayed tier rises, never on the first apply.

var _now: int = 10000


func _world() -> SimWorld:
	return SimWorld.new(SimConfigLoader.load_default(1))


func _model(w: SimWorld, level: int) -> UpgradeRowModel:
	var i: int = 0  # laser_output
	w.run_levels[i] = level
	var p: UpgradePreview = UpgradeSystem.preview(w, i, 1)
	return UpgradeRowModel.from_preview(p, p.affordable, p.level, w.config.upgrades[i])


func _row() -> UpgradeRow:
	var packed: PackedScene = load("res://src/ui/upgrade_row.tscn")
	var row: UpgradeRow = auto_free(packed.instantiate())
	add_child(row)
	row.tier_mark().clock = func() -> int: return _now
	return row


func _color(row: UpgradeRow) -> Color:
	return (row.get_node("%NextLabel") as Label).get_theme_color("font_color")


func test_first_apply_is_not_teal() -> void:
	var w: SimWorld = _world()
	var row: UpgradeRow = _row()
	row.apply(_model(w, 12))
	assert_bool(row.tier_mark().is_teal()).is_false()
	assert_object(_color(row)).is_equal(Palette.TEXT_DIM)


func test_tier_rise_turns_teal_for_three_seconds() -> void:
	var w: SimWorld = _world()
	var row: UpgradeRow = _row()
	row.apply(_model(w, 4))
	row.apply(_model(w, 5))
	assert_bool(row.tier_mark().is_teal()).is_true()
	assert_object(_color(row)).is_equal(Palette.TEAL)
	_now += 2900
	row.apply(_model(w, 5))
	assert_object(_color(row)).is_equal(Palette.TEAL)
	_now += 200
	row.apply(_model(w, 5))
	assert_bool(row.tier_mark().is_teal()).is_false()
	assert_object(_color(row)).is_equal(Palette.TEXT_DIM)


func test_same_tier_buy_and_top_mark_colors() -> void:
	var w: SimWorld = _world()
	var row: UpgradeRow = _row()
	row.apply(_model(w, 5))
	row.apply(_model(w, 6))
	assert_bool(row.tier_mark().is_teal()).is_false()
	row.apply(_model(w, 25))  # MK IV: a rise, teal first
	assert_object(_color(row)).is_equal(Palette.TEAL)
	_now += 3500
	row.apply(_model(w, 25))
	assert_object(_color(row)).is_equal(Palette.AMBER_TEXT)  # TOP MARK line
