class_name ThemeContrast
extends RefCounted
## High-contrast skin for the shared UI Theme (M4-24, 07 s5.4): text to full white (dim and disabled text to light
## grey), flat plate fills to black and plate borders to white, from the `high_contrast` rows of palettes.csv.
## Edits the Theme in place, so every control showing it updates at once. Originals are remembered in the theme's
## meta, so turning it off restores the exact normal colors. Textured plates (ui_kit 9-slices) keep their art.

const META_COLORS: StringName = &"hc_orig_colors"
const META_PLATE: StringName = &"hc_orig_plate"
const META_EDGE: StringName = &"hc_orig_edge"


## Switches `theme` to the high-contrast look (`on`) or back to the normal one. Not a per-frame call.
static func apply(theme: Theme, on: bool) -> void:
	var rules: PaletteSet = Palette.for_mode(Palette.HIGH_CONTRAST)
	_colors(theme, rules, on)
	for type_name: String in theme.get_stylebox_type_list():
		for sb_name: String in theme.get_stylebox_list(type_name):
			var sb: StyleBox = theme.get_stylebox(sb_name, type_name)
			if sb is StyleBoxFlat:
				_flat(sb as StyleBoxFlat, rules, on)


## The high-contrast color for a normal text color (unchanged for amber and other accents).
static func map_text(c: Color, rules: PaletteSet) -> Color:
	if c == Palette.TEXT:
		return rules.text
	if c == Palette.TEXT_DIM:
		return rules.text_dim
	if c == Palette.UNAFFORDABLE:
		return rules.text_disabled
	return c


static func _colors(theme: Theme, rules: PaletteSet, on: bool) -> void:
	var orig: Dictionary = theme.get_meta(META_COLORS, {})
	for type_name: String in theme.get_color_type_list():
		for c_name: String in theme.get_color_list(type_name):
			if not c_name.begins_with("font"):
				continue
			var key: String = "%s/%s" % [type_name, c_name]
			var cur: Color = theme.get_color(c_name, type_name)
			if not orig.has(key):
				orig[key] = cur
			var base: Color = orig[key]
			theme.set_color(c_name, type_name, map_text(base, rules) if on else base)
	theme.set_meta(META_COLORS, orig)


static func _flat(sb: StyleBoxFlat, rules: PaletteSet, on: bool) -> void:
	if not sb.has_meta(META_PLATE):
		sb.set_meta(META_PLATE, sb.bg_color)
		sb.set_meta(META_EDGE, sb.border_color)
	var plate: Color = sb.get_meta(META_PLATE)
	var edge: Color = sb.get_meta(META_EDGE)
	var opaque: bool = plate.a > 0.5
	sb.bg_color = rules.plate if (on and opaque) else plate
	sb.border_color = rules.edge if (on and edge.a > 0.5) else edge
