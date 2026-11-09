class_name IntelHub
extends VBoxContainer
## The INTEL tab content (M4-19): a STATS / WAVE sub-tab bar over the two read-only panels. Only the selected panel
## is visible (hidden panels skip their refresh). `UpgradePanel` hosts the hub in its scroll list.

const SUB_STATS: String = "stats"
const SUB_WAVE: String = "wave"
const SUB_IDS: Array[String] = [SUB_STATS, SUB_WAVE]
const TAB_HEIGHT: float = 148.0
const TAB_FONT: int = 42

var _stats: IntelPanel = IntelPanel.new()
var _wave: IntelWavePanel = IntelWavePanel.new()
var _buttons: Dictionary[String, Button] = {}
var _active: String = SUB_STATS


func _ready() -> void:
	theme = ThemeBuilder.shared()
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	var group := ButtonGroup.new()
	for id: String in SUB_IDS:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.text = Strings.get_text("intel.tab_" + id)
		b.custom_minimum_size = Vector2(0.0, TAB_HEIGHT)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		var normal: StyleBoxTexture = UiKit.tab(12, 10)
		var on: StyleBoxTexture = UiKit.tab_active(12, 10)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", normal)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover_pressed", on)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_font_size_override("font_size", TAB_FONT)
		for color_name: String in ["font_color", "font_hover_color", "font_focus_color"]:
			b.add_theme_color_override(color_name, Palette.AMBER)
		for color_name: String in ["font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(color_name, Palette.TEXT)
		b.pressed.connect(_on_pressed.bind(id))
		bar.add_child(b)
		_buttons[id] = b
	add_child(_stats)
	add_child(_wave)
	_show()


## Binds the world to both panels.
func bind(world: SimWorld) -> void:
	_stats.bind(world)
	_wave.bind(world)


func stats_panel() -> IntelPanel:
	return _stats


func wave_panel() -> IntelWavePanel:
	return _wave


func active_sub() -> String:
	return _active


## Selects STATS or WAVE; false for an unknown id.
func set_sub(id: String) -> bool:
	if not SUB_IDS.has(id):
		return false
	_active = id
	_show()
	return true


func sub_button(id: String) -> Button:
	return _buttons.get(id)


func _on_pressed(id: String) -> void:
	AudioHooks.tap()
	@warning_ignore("return_value_discarded")
	set_sub(id)


func _show() -> void:
	for id: String in _buttons:
		_buttons[id].set_pressed_no_signal(id == _active)
	_stats.visible = _active == SUB_STATS
	_wave.visible = _active == SUB_WAVE
