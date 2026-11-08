class_name TestThemeBuilder
extends GdUnitTestSuite


func test_contrast_ratio_known_values() -> void:
	assert_float(ThemeBuilder.contrast_ratio(Color.BLACK, Color.WHITE)).is_equal_approx(21.0, 0.01)
	assert_float(ThemeBuilder.contrast_ratio(Color.WHITE, Color.WHITE)).is_equal_approx(1.0, 0.001)
	var ab: float = ThemeBuilder.contrast_ratio(Palette.TEXT, Palette.PANEL)
	assert_float(ThemeBuilder.contrast_ratio(Palette.PANEL, Palette.TEXT)).is_equal_approx(ab, 0.0001)


func test_body_text_on_panel_meets_aa() -> void:
	assert_float(ThemeBuilder.contrast_ratio(Palette.TEXT, Palette.PANEL)).is_greater_equal(4.5)
	assert_float(ThemeBuilder.contrast_ratio(Palette.TEXT_DIM, Palette.PANEL)).is_greater_equal(4.5)


func test_amber_cost_text_on_panel_meets_aa() -> void:
	assert_float(ThemeBuilder.contrast_ratio(Palette.AMBER, Palette.PANEL)).is_greater_equal(4.5)
	var theme: Theme = ThemeBuilder.build()
	var normal: StyleBoxFlat = theme.get_stylebox("normal", "Button")
	assert_float(ThemeBuilder.contrast_ratio(Palette.AMBER, normal.bg_color)).is_greater_equal(4.5)


func test_theme_sets_fonts_for_label_and_button() -> void:
	var theme: Theme = ThemeBuilder.build()
	assert_object(theme.get_font("font", "Label")).is_not_null()
	assert_object(theme.get_font("font", "Button")).is_not_null()
	assert_bool(theme.has_font("font", "Label")).is_true()
	assert_bool(theme.has_font("font", "Button")).is_true()
	assert_object(theme.default_font).is_not_null()
	var number_font: Font = theme.get_font("font", ThemeBuilder.VAR_LABEL_NUMBER)
	assert_bool(number_font.get_font_name().begins_with("Share Tech Mono")).is_true()
	var body: Font = theme.get_font("font", "Label")
	assert_bool(body.get_font_name().begins_with("Oxanium")).is_true()


func test_font_sizes_meet_gdd_minimums() -> void:
	assert_int(ThemeBuilder.FONT_SIZE_BODY).is_greater_equal(ceili(14.0 * ThemeBuilder.PX_PER_DP))
	assert_int(ThemeBuilder.FONT_SIZE_NUMBER).is_greater_equal(ceili(16.0 * ThemeBuilder.PX_PER_DP))
	var theme: Theme = ThemeBuilder.build()
	assert_int(theme.get_font_size("font_size", "Label")).is_equal(ThemeBuilder.FONT_SIZE_BODY)
	assert_int(theme.get_font_size("font_size", ThemeBuilder.VAR_LABEL_NUMBER)).is_equal(ThemeBuilder.FONT_SIZE_NUMBER)
	assert_int(theme.get_font_size("font_size", ThemeBuilder.VAR_LABEL_HEADING)).is_equal(
		ThemeBuilder.FONT_SIZE_HEADING
	)


func test_label_colors_and_variations() -> void:
	var theme: Theme = ThemeBuilder.build()
	assert_that(theme.get_color("font_color", "Label")).is_equal(Palette.TEXT)
	assert_that(theme.get_color("font_color", ThemeBuilder.VAR_LABEL_DIM)).is_equal(Palette.TEXT_DIM)
	assert_that(theme.get_type_variation_base(ThemeBuilder.VAR_LABEL_DIM)).is_equal(&"Label")


func test_button_affordable_amber_unaffordable_not_red() -> void:
	var theme: Theme = ThemeBuilder.build()
	assert_that(theme.get_color("font_color", "Button")).is_equal(Palette.AMBER)
	var unaff: Color = theme.get_color("font_color", ThemeBuilder.VAR_BUTTON_UNAFFORDABLE)
	assert_that(unaff).is_equal(Palette.UNAFFORDABLE)
	assert_bool(unaff.r > unaff.g * 1.5).is_false()
	assert_that(theme.get_type_variation_base(ThemeBuilder.VAR_BUTTON_UNAFFORDABLE)).is_equal(&"Button")


func test_panel_and_touch_target() -> void:
	var theme: Theme = ThemeBuilder.build()
	var panel: StyleBoxFlat = theme.get_stylebox("panel", "PanelContainer")
	assert_that(panel.bg_color).is_equal(Palette.PANEL)
	var normal: StyleBoxFlat = theme.get_stylebox("normal", "Button")
	var min_h: float = normal.get_minimum_size().y + float(ThemeBuilder.FONT_SIZE_BODY)
	assert_float(min_h).is_greater_equal(56.0 * ThemeBuilder.PX_PER_DP - 8.0)
	assert_object(theme.get_stylebox("fill", "ProgressBar")).is_not_null()
	assert_object(theme.get_stylebox("tab_selected", "TabBar")).is_not_null()


func test_applies_to_real_controls() -> void:
	var theme: Theme = ThemeBuilder.build()
	var label: Label = auto_free(Label.new())
	label.theme = theme
	label.theme_type_variation = ThemeBuilder.VAR_LABEL_NUMBER
	add_child(label)
	assert_int(label.get_theme_font_size("font_size")).is_equal(ThemeBuilder.FONT_SIZE_NUMBER)
