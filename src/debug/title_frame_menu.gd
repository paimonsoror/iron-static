class_name TitleFrameMenu
extends Control
## Debug button row of the title style frame (tier, reduce motion, scanlines, forced flare and glitch). Desktop use;
## hidden for captures and measurements. Emits `action(id)`.

signal action(id: String)

const IDS: Array[String] = [
	"HIGH", "MID", "LOW", "MOTION", "SCAN", "FLARE", "GLITCH", "VANGUARD", "BULWARK", "STRIKER", "HIDE"
]

var _buttons: Dictionary = {}
var _row: HFlowContainer = null


func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HFlowContainer.new()
	_row.position = Vector2(16.0, 16.0)
	_row.custom_minimum_size = Vector2(700.0, 0.0)
	_row.size = Vector2(700.0, 10.0)
	add_child(_row)
	for id: String in IDS:
		var b := Button.new()
		b.text = id
		b.custom_minimum_size = Vector2(110.0 if id.length() < 8 else 190.0, 64.0)
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(_on_pressed.bind(id))
		_row.add_child(b)
		_buttons[id] = b


func set_label(id: String, text: String) -> void:
	if _buttons.has(id):
		var b: Button = _buttons[id]
		b.text = text


func set_shown(shown: bool) -> void:
	visible = shown


func _on_pressed(id: String) -> void:
	action.emit(id)
