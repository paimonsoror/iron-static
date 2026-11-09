class_name ThemeBuilder
extends RefCounted
## Builds the shared UI Theme in code from Palette (GDD 07 sections 1, 5.2, 5.4, 5.5).
## Not applied to scenes yet (M2-10/11 do that). Type variations (set a control's
## `theme_type_variation` to one of these):
##   Label:   LabelDim (TEXT_DIM), LabelNumber (mono, FONT_SIZE_NUMBER), LabelHeading (Oxanium, FONT_SIZE_HEADING)
##   Button:  ButtonUnaffordable (UNAFFORDABLE text, never red)
##   Panel:   PanelContainer uses PANEL; ProgressBar, TabContainer, TabBar styled too.

const FONT_BODY_PATH: String = "res://assets/fonts/Oxanium-Variable.ttf"
const FONT_NUMBER_PATH: String = "res://assets/fonts/ShareTechMono-Regular.ttf"

## Font sizes in px at the 1080 px wide base viewport. 1 dp = 1080 / 411 = 2.63 px, so
## the GDD minimums (text 14 sp = 36.8 px, numbers 16 sp = 42.1 px) force these values.
## The task's "16/18/22" would be about 6 dp and unreadable on a phone. (impl)
const PX_PER_DP: float = 2.63
const FONT_SIZE_BODY: int = 38
const FONT_SIZE_NUMBER: int = 44
const FONT_SIZE_HEADING: int = 54
## Primary touch target 56 dp = 147 px: buttons and tabs get at least this height.
const TOUCH_MIN_HEIGHT: int = 148
## Vertical content margin so button/tab height (margins + ~50 px line) is >= TOUCH_MIN_HEIGHT.
const MARGIN_V: int = 52

const VAR_LABEL_DIM: StringName = &"LabelDim"
const VAR_LABEL_NUMBER: StringName = &"LabelNumber"
const VAR_LABEL_HEADING: StringName = &"LabelHeading"
const VAR_BUTTON_UNAFFORDABLE: StringName = &"ButtonUnaffordable"
## V1-16 textured variations (built from `UiKit`; the defaults above stay flat until V1-17 switches the panel over):
##   PanelContainer/Panel: PanelPlate, PanelPlateActive, PanelInset; Button: ButtonPlate, ButtonAffordable,
##   ButtonChipActive (selected buy mode); TabBar/TabContainer: TabPlate.
const VAR_PANEL_PLATE: StringName = &"PanelPlate"
const VAR_PANEL_PLATE_ACTIVE: StringName = &"PanelPlateActive"
const VAR_PANEL_INSET: StringName = &"PanelInset"
const VAR_BUTTON_PLATE: StringName = &"ButtonPlate"
const VAR_BUTTON_AFFORDABLE: StringName = &"ButtonAffordable"
const VAR_BUTTON_CHIP_ACTIVE: StringName = &"ButtonChipActive"
const VAR_TAB_PLATE: StringName = &"TabPlate"
## V1-17: maxed cost button (plain plate, dim text).
const VAR_BUTTON_MAXED: StringName = &"ButtonMaxed"

const HEADING_WEIGHT: int = 600
## OpenType "wght" axis tag as an int (a StringName key is ignored by FontVariation: headings rendered light).
const WGHT_TAG: int = 0x77676874
const CORNER: int = 8

static var _shared: Theme = null


## One cached Theme for all screens (build() loads fonts and creates many styleboxes).
static func shared() -> Theme:
	if _shared == null:
		_shared = build()
		if Palette.active_contrast:
			ThemeContrast.apply(_shared, true)
	return _shared


## Re-skins the shared theme (if it was built) for high contrast on/off (M4-24); a later `shared()` honors it.
static func refresh_contrast(on: bool) -> void:
	if _shared != null:
		ThemeContrast.apply(_shared, on)


static func build() -> Theme:
	var theme := Theme.new()
	var body: Font = load(FONT_BODY_PATH)
	var number: Font = load(FONT_NUMBER_PATH)
	var heading := FontVariation.new()
	heading.base_font = body
	heading.variation_opentype = {WGHT_TAG: HEADING_WEIGHT}
	theme.default_font = body
	theme.default_font_size = FONT_SIZE_BODY

	_build_labels(theme, body, number, heading)
	_build_buttons(theme, body)
	_build_panels(theme)
	_build_tabs(theme, body)
	_build_progress(theme)
	_build_plates(theme)
	return theme


## WCAG 2.x contrast ratio, 1.0 (identical) to 21.0 (black on white).
static func contrast_ratio(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	var hi: float = maxf(la, lb)
	var lo: float = minf(la, lb)
	return (hi + 0.05) / (lo + 0.05)


static func _luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _lin(v: float) -> float:
	if v <= 0.03928:
		return v / 12.92
	return pow((v + 0.055) / 1.055, 2.4)


static func _box(fill: Color, border: Color, margin_h: int, margin_v: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(CORNER)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb


static func _button_fill() -> Color:
	return Palette.PANEL.lerp(Color.WHITE, 0.07)


static func _build_labels(theme: Theme, body: Font, number: Font, heading: Font) -> void:
	theme.set_font("font", "Label", body)
	theme.set_font_size("font_size", "Label", FONT_SIZE_BODY)
	theme.set_color("font_color", "Label", Palette.TEXT)

	theme.set_type_variation(VAR_LABEL_DIM, "Label")
	theme.set_color("font_color", VAR_LABEL_DIM, Palette.TEXT_DIM)

	theme.set_type_variation(VAR_LABEL_NUMBER, "Label")
	theme.set_font("font", VAR_LABEL_NUMBER, number)
	theme.set_font_size("font_size", VAR_LABEL_NUMBER, FONT_SIZE_NUMBER)

	theme.set_type_variation(VAR_LABEL_HEADING, "Label")
	theme.set_font("font", VAR_LABEL_HEADING, heading)
	theme.set_font_size("font_size", VAR_LABEL_HEADING, FONT_SIZE_HEADING)


static func _build_buttons(theme: Theme, body: Font) -> void:
	var margin_v: int = MARGIN_V
	var normal := _box(_button_fill(), Palette.AMBER_DIM, 28, margin_v)
	var hover := _box(_button_fill().lerp(Palette.AMBER, 0.10), Palette.AMBER, 28, margin_v)
	var pressed := _box(_button_fill().lerp(Palette.AMBER, 0.22), Palette.AMBER_GLOW, 28, margin_v)
	var disabled := _box(Palette.PANEL, Palette.UNAFFORDABLE, 28, margin_v)
	var focus := _box(Color(0, 0, 0, 0), Palette.AMBER_GLOW, 28, margin_v)
	theme.set_font("font", "Button", body)
	theme.set_font_size("font_size", "Button", FONT_SIZE_BODY)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", focus)
	# Affordable = amber text.
	theme.set_color("font_color", "Button", Palette.AMBER)
	theme.set_color("font_hover_color", "Button", Palette.AMBER_GLOW)
	theme.set_color("font_pressed_color", "Button", Palette.AMBER_GLOW)
	theme.set_color("font_focus_color", "Button", Palette.AMBER)
	theme.set_color("font_disabled_color", "Button", Palette.UNAFFORDABLE)

	# Unaffordable = muted brown-grey, never red (red is hostile only).
	theme.set_type_variation(VAR_BUTTON_UNAFFORDABLE, "Button")
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(state, VAR_BUTTON_UNAFFORDABLE, Palette.UNAFFORDABLE)
	theme.set_stylebox("normal", VAR_BUTTON_UNAFFORDABLE, disabled)
	theme.set_stylebox("hover", VAR_BUTTON_UNAFFORDABLE, disabled)
	theme.set_stylebox("pressed", VAR_BUTTON_UNAFFORDABLE, disabled)


static func _build_panels(theme: Theme) -> void:
	var panel := _box(Palette.PANEL, Palette.GRID, 24, 24)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)


static func _build_tabs(theme: Theme, body: Font) -> void:
	var margin_v: int = MARGIN_V
	var selected := _box(Palette.PANEL, Palette.AMBER, 24, margin_v)
	var unselected := _box(Palette.GRID, Palette.GRID, 24, margin_v)
	var hovered := _box(Palette.GRID.lerp(Palette.AMBER, 0.10), Palette.AMBER_DIM, 24, margin_v)
	for type_name: String in ["TabContainer", "TabBar"]:
		theme.set_font("font", type_name, body)
		theme.set_font_size("font_size", type_name, FONT_SIZE_BODY)
		theme.set_stylebox("tab_selected", type_name, selected)
		theme.set_stylebox("tab_unselected", type_name, unselected)
		theme.set_stylebox("tab_hovered", type_name, hovered)
		theme.set_color("font_selected_color", type_name, Palette.AMBER)
		theme.set_color("font_unselected_color", type_name, Palette.TEXT_DIM)
		theme.set_color("font_hovered_color", type_name, Palette.TEXT)
	theme.set_stylebox("panel", "TabContainer", _box(Palette.PANEL, Palette.GRID, 24, 24))


static func _build_progress(theme: Theme) -> void:
	var bg := _box(Palette.GRID, Palette.GRID, 0, 0)
	var fill := _box(Palette.AMBER, Palette.AMBER, 0, 0)
	theme.set_stylebox("background", "ProgressBar", bg)
	theme.set_stylebox("fill", "ProgressBar", fill)
	theme.set_color("font_color", "ProgressBar", Palette.TEXT)
	theme.set_font_size("font_size", "ProgressBar", FONT_SIZE_BODY)


## Textured variations from the ui_kit 9-slices (V1-16). Content margins follow the old flat boxes so sizes match.
static func _build_plates(theme: Theme) -> void:
	for pair: Array in [
		[VAR_PANEL_PLATE, UiKit.plate(24, 24)],
		[VAR_PANEL_PLATE_ACTIVE, UiKit.plate_active(24, 24)],
		[VAR_PANEL_INSET, UiKit.inset(24, 24)],
	]:
		var var_name: StringName = pair[0]
		var sb: StyleBoxTexture = pair[1]
		theme.set_type_variation(var_name, "PanelContainer")
		theme.set_stylebox("panel", var_name, sb)
	var m: int = MARGIN_V
	theme.set_type_variation(VAR_BUTTON_PLATE, "Button")
	theme.set_stylebox("normal", VAR_BUTTON_PLATE, UiKit.button(28, m))
	theme.set_stylebox("hover", VAR_BUTTON_PLATE, UiKit.button(28, m))
	theme.set_stylebox("pressed", VAR_BUTTON_PLATE, UiKit.button_pressed(28, m))
	theme.set_stylebox("disabled", VAR_BUTTON_PLATE, UiKit.button_disabled(28, m))
	theme.set_type_variation(VAR_BUTTON_AFFORDABLE, VAR_BUTTON_PLATE)
	theme.set_stylebox("normal", VAR_BUTTON_AFFORDABLE, UiKit.button_affordable(28, m))
	theme.set_stylebox("hover", VAR_BUTTON_AFFORDABLE, UiKit.button_affordable(28, m))
	theme.set_type_variation(VAR_BUTTON_CHIP_ACTIVE, VAR_BUTTON_PLATE)
	theme.set_stylebox("normal", VAR_BUTTON_CHIP_ACTIVE, UiKit.button_active(28, m))
	theme.set_stylebox("hover", VAR_BUTTON_CHIP_ACTIVE, UiKit.button_active(28, m))
	theme.set_type_variation(VAR_TAB_PLATE, "TabBar")
	theme.set_stylebox("tab_selected", VAR_TAB_PLATE, UiKit.tab_active(24, m))
	theme.set_stylebox("tab_unselected", VAR_TAB_PLATE, UiKit.tab(24, m))
	theme.set_stylebox("tab_hovered", VAR_TAB_PLATE, UiKit.tab(24, m))
	# V1-17: the unaffordable cost button wears the dim plate (same text color, never red); MAX wears the plain plate.
	for state: String in ["normal", "hover", "pressed"]:
		theme.set_stylebox(state, VAR_BUTTON_UNAFFORDABLE, UiKit.button_disabled(28, m))
	theme.set_type_variation(VAR_BUTTON_MAXED, VAR_BUTTON_PLATE)
	theme.set_stylebox("disabled", VAR_BUTTON_MAXED, UiKit.button(28, m))
	theme.set_color("font_disabled_color", VAR_BUTTON_MAXED, Palette.TEXT_DIM)
