class_name SettingsChoice
extends HBoxContainer
## Segmented selector (M3-18): one plate button per option, the selected one wears the active plate. `dimmed`
## greys every button and blocks input but keeps the stored selection visible (reduce motion).

signal chosen(index: int)

const FONT_PX: int = 44

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
		b.add_theme_font_size_override("font_size", FONT_PX)
		b.pressed.connect(_on_pressed.bind(i))
		add_child(b)
		buttons.append(b)
	selected = index
	_restyle()


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
