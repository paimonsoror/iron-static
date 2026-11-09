class_name TestPalettes
extends GdUnitTestSuite

## M4-24: palettes.csv defines every role, the roles stay distinguishable under simulated colour vision
## deficiency, high-contrast text meets WCAG 4.5:1 on its plate, and the live hook reaches the renderer.

## Minimum CIE76 delta E between any two of amber / teal / hostile / fire as seen in the mode (just noticeable is
## about 2.3). The measured minimum is about 30 (deuteranopia hostile vs teal); the baseline palette is 72.
const MIN_DELTA_E: float = 25.0
## Hostile vs teal also differ in lightness: WCAG luminance ratio floor per mode (lowest is deuteranopia, 1.39, with the
## 07 s5.4 colors; hue and shape carry the rest).
const MIN_HOSTILE_TEAL_RATIO: float = 1.3
const MODES: Array[String] = ["off", "deuteranopia", "protanopia", "tritanopia"]
const ROLES: Array[String] = ["amber", "teal", "hostile", "fire"]


func after_test() -> void:
	Palette.set_active("off", false)
	ThemeBuilder.refresh_contrast(false)


func _color(s: PaletteSet, role: String) -> Color:
	match role:
		"amber":
			return s.amber
		"teal":
			return s.teal
		"hostile":
			return s.hostile
	return s.fire


func _tint(m: ShaderMaterial) -> Vector3:
	var v: Vector3 = m.get_shader_parameter("tint_hostile")
	return v


func test_every_mode_defines_all_roles() -> void:
	var text: String = FileAccess.get_file_as_string(Palette.PALETTES_PATH)
	for mode: String in MODES:
		for role: String in ROLES + ["critical"]:
			assert_bool(text.contains("\n%s,%s,#" % [mode, role])).is_true()
	for role: String in ["text", "text_dim", "text_disabled", "plate", "edge", "bg_dim"]:
		assert_bool(text.contains("\nhigh_contrast,%s," % role)).is_true()


func test_off_is_the_baked_palette() -> void:
	var p: PaletteSet = Palette.for_mode("off")
	assert_object(p.hostile).is_equal(Palette.ENEMY_OUTLINE)
	assert_object(p.teal).is_equal(Palette.TEAL)
	assert_object(p.amber).is_equal(Palette.AMBER)
	assert_object(p.fire).is_equal(Palette.ENEMY_FIRE)
	assert_vector(p.tint_hostile).is_equal(Vector3.ONE)
	assert_vector(p.tint_fire).is_equal(Vector3.ONE)
	assert_object(Palette.for_mode("nonsense")).is_same(p)


func test_pairs_stay_distinct_in_every_simulated_mode() -> void:
	for mode: String in MODES:
		var p: PaletteSet = Palette.for_mode(mode)
		for i: int in ROLES.size():
			for j: int in range(i + 1, ROLES.size()):
				var de: float = CvdSim.delta_e(_color(p, ROLES[i]), _color(p, ROLES[j]), mode)
				(
					assert_float(de)
					. override_failure_message("%s: %s vs %s dE %.1f" % [mode, ROLES[i], ROLES[j], de])
					. is_greater(MIN_DELTA_E)
				)


func test_hostile_and_teal_have_a_luminance_gap() -> void:
	for mode: String in MODES:
		var p: PaletteSet = Palette.for_mode(mode)
		var r: float = CvdSim.luminance_ratio(p.hostile, p.teal, mode)
		assert_float(r).override_failure_message("%s hostile/teal ratio %.2f" % [mode, r]).is_greater(
			MIN_HOSTILE_TEAL_RATIO
		)


func test_integrity_ramp_ends_differ_in_every_mode() -> void:
	for mode: String in MODES:
		var p: PaletteSet = Palette.for_mode(mode)
		assert_float(CvdSim.delta_e(p.critical, p.teal, mode)).is_greater(MIN_DELTA_E)
		assert_float(CvdSim.delta_e(p.critical, p.amber, mode)).is_greater(MIN_DELTA_E)


func test_simulation_sanity() -> void:
	for mode: String in ["deuteranopia", "protanopia", "tritanopia"]:
		assert_float(CvdSim.delta_e(Color.WHITE, Color(0.5, 0.5, 0.5), mode)).is_greater(40.0)
		var w: PackedFloat64Array = CvdSim.linear_seen(Color.WHITE, mode)
		assert_float(w[0]).is_between(0.99, 1.0)
		assert_float(w[2]).is_between(0.99, 1.0)
	var red := Color("#FF0000")
	var green := Color("#00A000")
	assert_float(CvdSim.delta_e(red, green, "deuteranopia")).is_less(CvdSim.delta_e(red, green, "off") * 0.6)


func test_tints_reproduce_the_palette_on_the_baked_colors() -> void:
	for mode: String in MODES:
		var p: PaletteSet = Palette.for_mode(mode)
		var out := Color(
			minf(Palette.ENEMY_OUTLINE.r * p.tint_hostile.x, 1.0),
			minf(Palette.ENEMY_OUTLINE.g * p.tint_hostile.y, 1.0),
			minf(Palette.ENEMY_OUTLINE.b * p.tint_hostile.z, 1.0)
		)
		assert_bool(out.is_equal_approx(p.hostile)).override_failure_message(mode).is_true()


func test_high_contrast_text_meets_wcag_on_the_plate() -> void:
	var hc: PaletteSet = Palette.for_mode(Palette.HIGH_CONTRAST)
	for c: Color in [hc.text, hc.text_dim, hc.text_disabled, Palette.AMBER, Palette.TEAL, Palette.DATA]:
		var r: float = ThemeBuilder.contrast_ratio(c, hc.plate)
		assert_float(r).override_failure_message("%s on plate %.2f" % [c.to_html(), r]).is_greater_equal(4.5)
	assert_float(ThemeBuilder.contrast_ratio(hc.edge, hc.plate)).is_greater_equal(4.5)
	assert_float(hc.bg_dim).is_between(0.2, 0.7)


func test_high_contrast_reskins_and_restores_the_theme() -> void:
	var theme: Theme = ThemeBuilder.build()
	var before: Color = theme.get_color("font_color", "Label")
	var panel: StyleBoxFlat = theme.get_stylebox("panel", "PanelContainer") as StyleBoxFlat
	var edge0: Color = panel.border_color
	ThemeContrast.apply(theme, true)
	var hc: PaletteSet = Palette.for_mode(Palette.HIGH_CONTRAST)
	assert_object(theme.get_color("font_color", "Label")).is_equal(hc.text)
	assert_object(theme.get_color("font_color", ThemeBuilder.VAR_LABEL_DIM)).is_equal(hc.text_dim)
	assert_object(panel.border_color).is_equal(hc.edge)
	assert_object(panel.bg_color).is_equal(hc.plate)
	ThemeContrast.apply(theme, false)
	assert_object(theme.get_color("font_color", "Label")).is_equal(before)
	assert_object(panel.border_color).is_equal(edge0)


func test_accessibility_hook_sets_active_palette_and_dims_background() -> void:
	var v := VisualSettings.new()
	v.set_accessibility("protanopia", true)
	assert_object(Palette.current()).is_same(Palette.for_mode("protanopia"))
	assert_bool(Palette.active_contrast).is_true()
	assert_float(v.background_dim()).is_equal(Palette.for_mode(Palette.HIGH_CONTRAST).bg_dim)
	assert_float(v.effective_scanlines()).is_equal(0.0)
	v.set_accessibility("protanopia", false)
	assert_float(v.background_dim()).is_equal(1.0)
	assert_float(v.effective_scanlines()).is_greater(0.0)


func test_ramp_colors_follow_the_active_palette() -> void:
	assert_bool(SegmentedBar.ramp_color(1.0).is_equal_approx(Palette.TEAL)).is_true()
	assert_bool(SegmentedBar.ramp_color(0.0).is_equal_approx(Palette.CRITICAL)).is_true()
	Palette.set_active("tritanopia", false)
	assert_bool(SegmentedBar.ramp_color(1.0).is_equal_approx(Palette.for_mode("tritanopia").teal)).is_true()
	Palette.set_active("deuteranopia", false)
	assert_bool(SegmentedBar.ramp_color(0.0).is_equal_approx(Palette.for_mode("deuteranopia").critical)).is_true()


func test_enemy_renderer_applies_tints_live_and_without_resizing() -> void:
	var r := EnemyRenderer.new()
	add_child(r)
	var v := VisualSettings.new()
	r.visual = v
	r.setup(33.75, PackedFloat32Array([0.4, 0.4, 0.5, 0.5, 2.0]))
	var resizes: int = r.resize_count
	var mat: ShaderMaterial = (r.get_child(0) as MultiMeshInstance2D).material as ShaderMaterial
	var bolt: ShaderMaterial = (r.get_child(5) as MultiMeshInstance2D).material as ShaderMaterial
	assert_vector(_tint(mat)).is_equal(Vector3.ONE)
	v.set_accessibility("deuteranopia", false)
	var pal: PaletteSet = Palette.for_mode("deuteranopia")
	assert_vector(_tint(mat)).is_equal(pal.tint_hostile)
	assert_vector(_tint(bolt)).is_equal(pal.tint_fire)
	v.set_accessibility("off", false)
	assert_vector(_tint(mat)).is_equal(Vector3.ONE)
	assert_int(r.resize_count).is_equal(resizes)
	r.queue_free()
