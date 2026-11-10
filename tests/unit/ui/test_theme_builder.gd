class_name TestThemeBuilder
extends GdUnitTestSuite

## R1-07: WCAG AA for text.
const MIN_TEXT_CONTRAST: float = 4.5


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


## Q48 / R1-07: every text color on the background it is drawn on reaches WCAG AA (4.5:1), in the normal, the three
## colorblind and the high-contrast palettes. Large decorative colors (enemy art, beam) are not text and not listed.


func _below(pairs: Array, label: String) -> Array[String]:
	var bad: Array[String] = []
	for pair: Array in pairs:
		var fg: Color = pair[0]
		var bg: Color = pair[1]
		var ratio: float = ThemeBuilder.contrast_ratio(fg, bg)
		if ratio < MIN_TEXT_CONTRAST:
			bad.append("%s %s on %s %s = %.2f" % [label, fg.to_html(false), bg.to_html(false), pair[2], ratio])
	return bad


func test_every_text_color_meets_aa_on_its_background() -> void:
	var pairs: Array = []
	for bg: Color in [Palette.PANEL, Palette.VOID, Palette.PLATE_SHADOW, Palette.GRID]:
		for fg: Color in [
			Palette.TEXT,
			Palette.TEXT_DIM,
			Palette.AMBER,
			Palette.AMBER_GLOW,
			Palette.AMBER_TEXT,
			Palette.UNAFFORDABLE,
			Palette.OVER_LIMIT,
			Palette.TEAL,
			Palette.WARNING,
			Palette.CRITICAL,
			Palette.SCRAP,
			Palette.DATA,
			Palette.FLUX,
			Palette.CIPHER,
			Palette.MERIT,
		]:
			pairs.append([fg, bg, "(palette)"])
	assert_array(_below(pairs, "normal")).is_empty()


func test_unaffordable_and_dim_amber_text_were_lifted() -> void:
	assert_that(Palette.UNAFFORDABLE).is_equal(Color("#8A8170"))
	assert_that(Palette.AMBER_TEXT).is_equal(Color("#B88A1E"))
	assert_that(Palette.AMBER_DIM).is_equal(Color("#8A5F00"))  # lines and frames keep the dim value
	assert_float(ThemeBuilder.contrast_ratio(Palette.UNAFFORDABLE, Palette.PANEL)).is_greater_equal(4.5)
	assert_float(ThemeBuilder.contrast_ratio(Palette.AMBER_TEXT, Palette.PANEL)).is_greater_equal(4.5)
	assert_float(ThemeBuilder.contrast_ratio(Palette.AMBER_DIM, Palette.PANEL)).is_less(4.5)  # why it is not text


func test_colorblind_palette_text_colors_meet_aa() -> void:
	var pairs: Array = []
	for mode: String in Palette.MODES:
		var pal: PaletteSet = Palette.for_mode(mode)
		for bg: Color in [Palette.PANEL, Palette.VOID]:
			for fg: Color in [pal.amber, pal.teal, pal.critical, Palette.OVER_LIMIT]:
				pairs.append([fg, bg, mode])
	assert_array(_below(pairs, "mode")).is_empty()


func test_high_contrast_text_meets_aa() -> void:
	var rules: PaletteSet = Palette.for_mode(Palette.HIGH_CONTRAST)
	var pairs: Array = []
	for fg: Color in [
		rules.text,
		rules.text_dim,
		rules.text_disabled,
		Palette.AMBER,
		Palette.AMBER_GLOW,
		Palette.AMBER_TEXT,
		Palette.OVER_LIMIT,
		Palette.TEAL,
	]:
		pairs.append([fg, rules.plate, "high_contrast plate"])
		pairs.append([fg, Palette.VOID, "high_contrast void"])
	assert_array(_below(pairs, "hc")).is_empty()


## The real Theme: each font color of Label, Button and the tab types against the flat style box it is drawn on,
## with high contrast off and on.
func test_theme_font_colors_meet_aa_on_their_boxes() -> void:
	for contrast: bool in [false, true]:
		var theme: Theme = ThemeBuilder.build()
		ThemeContrast.apply(theme, contrast)
		var pairs: Array = []
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var sb: StyleBox = theme.get_stylebox(state, "Button")
			var color_name: String = "font_color" if state == "normal" else "font_%s_color" % state
			var flat: StyleBoxFlat = sb as StyleBoxFlat
			pairs.append([theme.get_color(color_name, "Button"), flat.bg_color, "Button " + state])
		var dark: StyleBoxFlat = theme.get_stylebox("disabled", "Button") as StyleBoxFlat  # plate of the unaffordable cost
		pairs.append(
			[theme.get_color("font_color", ThemeBuilder.VAR_BUTTON_UNAFFORDABLE), dark.bg_color, "unaffordable"]
		)
		var panel: StyleBoxFlat = theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
		pairs.append([theme.get_color("font_color", "Label"), panel.bg_color, "Label"])
		pairs.append([theme.get_color("font_color", ThemeBuilder.VAR_LABEL_DIM), panel.bg_color, "LabelDim"])
		var tab_on: StyleBoxFlat = theme.get_stylebox("tab_selected", "TabBar") as StyleBoxFlat
		var tab_off: StyleBoxFlat = theme.get_stylebox("tab_unselected", "TabBar") as StyleBoxFlat
		pairs.append([theme.get_color("font_selected_color", "TabBar"), tab_on.bg_color, "tab selected"])
		pairs.append([theme.get_color("font_unselected_color", "TabBar"), tab_off.bg_color, "tab unselected"])
		assert_array(_below(pairs, "theme hc=%s" % contrast)).is_empty()


func test_body_font_uses_the_medium_weight() -> void:
	# Oxanium-Variable.ttf has one axis, wght 200-800, default 200 (the thin look of I-05): body text is varied to 500.
	assert_int(ThemeBuilder.BODY_WEIGHT).is_between(500, 600)
	var theme: Theme = ThemeBuilder.build()
	for type_name: String in ["Label", "Button", "TabBar", "TabContainer"]:
		var font: Font = theme.get_font("font", type_name)
		assert_bool(font is FontVariation).is_true()
		var fv: FontVariation = font as FontVariation
		assert_int(_wght(fv)).is_equal(ThemeBuilder.BODY_WEIGHT)
	var def_font: FontVariation = theme.default_font as FontVariation
	assert_int(_wght(def_font)).is_equal(ThemeBuilder.BODY_WEIGHT)
	var heading: FontVariation = theme.get_font("font", ThemeBuilder.VAR_LABEL_HEADING) as FontVariation
	assert_int(_wght(heading)).is_equal(ThemeBuilder.HEADING_WEIGHT)


static func _wght(fv: FontVariation) -> int:
	var v: Variant = fv.variation_opentype.get(ThemeBuilder.WGHT_TAG, 0)
	return v if v is int else 0
