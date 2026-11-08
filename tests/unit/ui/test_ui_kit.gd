class_name TestUiKit
extends GdUnitTestSuite
## UiKit style API (V1-16): styleboxes come from the slots.csv rows (cell rect and 9-slice margins).


func test_plate_uses_slot_cell_and_margins() -> void:
	var art: ArtSlot = ArtSlots.slot("ui_panel_plate")
	var sb: StyleBoxTexture = UiKit.plate()
	assert_bool(sb.region_rect == art.frame_rect(0)).is_true()
	assert_float(sb.texture_margin_left).is_equal(art.pivot.x)
	assert_float(sb.texture_margin_top).is_equal(art.pivot.y)
	assert_float(sb.texture_margin_left).is_equal(28.0)


func test_every_builder_returns_a_distinct_valid_box() -> void:
	var boxes: Array[StyleBoxTexture] = [
		UiKit.plate(),
		UiKit.plate_active(),
		UiKit.inset(),
		UiKit.tooltip(),
		UiKit.button(),
		UiKit.button_pressed(),
		UiKit.button_disabled(),
		UiKit.button_affordable(),
		UiKit.button_active(),
		UiKit.tab(),
		UiKit.tab_active(),
		UiKit.bar_frame(),
		UiKit.hazard_stripe(),
	]
	for sb: StyleBoxTexture in boxes:
		assert_object(sb.texture).is_not_null()
		assert_float(sb.region_rect.size.x).is_greater(0.0)
	var a: StyleBoxTexture = UiKit.plate()
	assert_bool(a != UiKit.plate()).is_true()
	assert_bool(UiKit.button().region_rect == UiKit.button_active().region_rect).is_false()


func test_hazard_stripe_tiles_horizontally() -> void:
	var sb: StyleBoxTexture = UiKit.hazard_stripe()
	assert_int(sb.axis_stretch_horizontal).is_equal(StyleBoxTexture.AXIS_STRETCH_MODE_TILE)


func test_content_margins_are_passed_through() -> void:
	var sb: StyleBoxTexture = UiKit.button(28, 52)
	assert_float(sb.get_minimum_size().x).is_equal(56.0)
	assert_float(sb.get_minimum_size().y).is_equal(104.0)


func test_icon_button_keeps_touch_rect_and_swaps_icons() -> void:
	var b: Button = auto_free(Button.new())
	b.custom_minimum_size = Vector2(148, 148)
	UiKit.style_icon_button(b, "icon_ic_pause")
	var first: Texture2D = b.icon
	UiKit.set_icon(b, "icon_ic_play")
	assert_bool(b.icon != first).is_true()
	assert_float(b.custom_minimum_size.y).is_greater_equal(148.0)


func test_theme_has_plate_variations() -> void:
	var t: Theme = ThemeBuilder.build()
	assert_bool(t.has_stylebox("panel", ThemeBuilder.VAR_PANEL_PLATE)).is_true()
	assert_bool(t.has_stylebox("normal", ThemeBuilder.VAR_BUTTON_AFFORDABLE)).is_true()
	assert_bool(t.has_stylebox("tab_selected", ThemeBuilder.VAR_TAB_PLATE)).is_true()
	assert_bool(t.get_stylebox("normal", ThemeBuilder.VAR_BUTTON_PLATE) is StyleBoxTexture).is_true()
