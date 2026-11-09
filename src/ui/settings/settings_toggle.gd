class_name SettingsToggle
extends Button
## Full-row on/off toggle (M3-18): label on the left, a switch on the right (amber when on). Plate button,
## >= 148 px tall. `toggled(bool)` fires on a player tap only; `set_value_silent` never emits.

const FONT_PX: int = 46
const SW_W: float = 120.0
const SW_H: float = 60.0


func _init() -> void:
	toggle_mode = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	theme_type_variation = ThemeBuilder.VAR_BUTTON_PLATE
	custom_minimum_size = Vector2(0.0, float(ThemeBuilder.TOUCH_MIN_HEIGHT))
	add_theme_font_size_override("font_size", FONT_PX)
	for c: String in ["font_color", "font_pressed_color", "font_hover_pressed_color", "font_hover_color"]:
		add_theme_color_override(c, Palette.TEXT)


func set_value_silent(on: bool) -> void:
	set_pressed_no_signal(on)
	queue_redraw()


func _toggled(_on: bool) -> void:
	AudioHooks.tap()
	queue_redraw()


func _draw() -> void:
	var on: bool = button_pressed
	var r := Rect2(size.x - SW_W - 28.0, (size.y - SW_H) * 0.5, SW_W, SW_H)
	draw_rect(r, Palette.AMBER_DIM if on else Palette.GRID)
	draw_rect(r, Palette.AMBER if on else Palette.UNAFFORDABLE, false, 3.0)
	var kx: float = r.end.x - SW_H + 6.0 if on else r.position.x + 6.0
	var knob := Rect2(kx, r.position.y + 6.0, SW_H - 12.0, SW_H - 12.0)
	draw_rect(knob, Palette.AMBER_GLOW if on else Palette.TEXT_DIM)
