class_name MenuScreen
extends Control
## Base of every full-screen menu screen (M3-14): themed root, safe-area margins, the 1080 px `MenuColumn` in
## the wide layout, a dark background, a heading and a `content` VBox the screen fills.
## For screen authors (M3-15/16/18/28/29): subclass this, override `title_key()` (and `_build()`), add children
## to `content` (a `VBoxContainer`, already positioned inside the safe area and the column), emit your signals,
## override `enter()` to refresh from `Game` each time the screen is shown and `on_back()` only to consume back
## (return true) for an inner dialog; the router handles the rest. Never edit `main.gd`: see `ScreenRouter`.
## Menu screens never tick the sim; read `Game.profile()` / `Game.saves` / `Game.audio` directly.

const BUTTON_FONT_PX: int = 54
const SEPARATION: int = 40

## Holds the screen's widgets (heading first).
var content: VBoxContainer
## The heading label (hidden when `title_key()` is "").
var heading: Label
var _safe := Vector4.ZERO
var _mode: LayoutMode.Mode = LayoutMode.Mode.PORTRAIT


func _ready() -> void:
	theme = ThemeBuilder.shared()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Palette.VOID
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	content = VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", SEPARATION)
	add_child(content)
	heading = label(title_key(), &"LabelHeading", Palette.AMBER, 96)
	heading.visible = title_key() != ""
	content.add_child(heading)
	resized.connect(_layout)
	_build()
	_layout()


## String key of the heading ("" for none). Override.
func title_key() -> String:
	return ""


## Add widgets to `content` here (runs once, after the base is built). Override.
func _build() -> void:
	pass


## Called by the router every time the screen becomes visible. Override to refresh from `Game`.
func enter() -> void:
	pass


## Called when the screen is hidden. Override.
func leave() -> void:
	pass


## Back gesture hook: return true when an inner dialog consumed it. Override.
func on_back() -> bool:
	return false


## Safe margins (left, top, right, bottom viewport px); called by the router on show and on every change.
func apply_safe_margins(m: Vector4) -> void:
	_safe = m
	_layout()


func layout_mode() -> LayoutMode.Mode:
	return _mode


## The rect `content` occupies (safe area, 1080 column in WIDE), in this control's pixels.
func column_rect() -> Rect2:
	return MenuColumn.rect(size, _safe, _mode)


func _layout() -> void:
	if content == null:
		return
	_mode = LayoutMode.pick(size, _mode)
	var r: Rect2 = column_rect()
	content.position = r.position
	content.size = r.size


## A themed label from a string key.
static func label(key: String, variation: StringName, color: Color, size_px: int) -> Label:
	var l := Label.new()
	l.text = Strings.get_text(key) if key != "" else ""
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size_px)
	return l


## A full-width plate button (touch target >= 148 px) wired to `on_pressed`.
static func make_button(key: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = Strings.get_text(key)
	b.theme_type_variation = ThemeBuilder.VAR_BUTTON_PLATE
	b.custom_minimum_size = Vector2(0.0, float(ThemeBuilder.TOUCH_MIN_HEIGHT))
	b.add_theme_font_size_override("font_size", BUTTON_FONT_PX)
	b.add_theme_color_override("font_color", Palette.AMBER_GLOW)
	b.pressed.connect(on_pressed)
	return b
