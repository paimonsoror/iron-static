class_name SettingsChoice
extends HBoxContainer
## Segmented selector (M3-18): one plate button per option, the selected one wears the active plate. `dimmed`
## greys every button and blocks input but keeps the stored selection visible (reduce motion).

signal chosen(index: int)

const FONT_PX: int = 44
## Body-text floor (CLAUDE.md): a long option shrinks toward this before the segment is given up on.
const MIN_FONT_PX: int = 38
## Extra characters added to an option text length for its segment weight (longer words get a wider segment).
const RATIO_PAD_CHARS: int = 4

var selected: int = 0
var dimmed: bool = false
var buttons: Array[Button] = []


func setup(label_keys: Array[String], index: int) -> void:
	add_theme_constant_override("separation", 12)
	for i: int in label_keys.size():
		var b := Button.new()
		b.text = Strings.get_text(label_keys[i])
		b.custom_minimum_size = Vector2(0.0, float(ThemeBuilder.TOUCH_MIN_HEIGHT))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.size_flags_stretch_ratio = float(b.text.length() + RATIO_PAD_CHARS)
		b.add_theme_font_size_override("font_size", FONT_PX)
		b.pressed.connect(_on_pressed.bind(i))
		add_child(b)
		buttons.append(b)
	sort_children.connect(fit_fonts)
	selected = index
	_restyle()


## Largest font size in MIN_FONT_PX..FONT_PX at which each option text fits its button (called on resize).
func fit_fonts() -> void:
	for b: Button in buttons:
		var font: Font = b.get_theme_font("font")
		var room: float = b.size.x - b.get_theme_stylebox("normal").get_minimum_size().x
		var px: int = FONT_PX
		while px > MIN_FONT_PX and font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x > room:
			px -= 1
		b.add_theme_font_size_override("font_size", px)


func set_selected_silent(index: int) -> void:
	selected = clampi(index, 0, maxi(buttons.size() - 1, 0))
	_restyle()


func set_dimmed(on: bool) -> void:
	dimmed = on
	_restyle()


func _on_pressed(i: int) -> void:
	AudioHooks.tap()
	if i == selected:
		return
	selected = i
	_restyle()
	chosen.emit(i)


func _restyle() -> void:
	for i: int in buttons.size():
		var b: Button = buttons[i]
		var on: bool = i == selected
		b.theme_type_variation = ThemeBuilder.VAR_BUTTON_CHIP_ACTIVE if on else ThemeBuilder.VAR_BUTTON_PLATE
		b.disabled = dimmed
		b.add_theme_color_override("font_color", Palette.AMBER_GLOW if on else Palette.TEXT_DIM)
		b.add_theme_color_override("font_disabled_color", Palette.TEXT_DIM if on else Palette.UNAFFORDABLE)
