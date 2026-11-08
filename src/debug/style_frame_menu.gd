class_name StyleFrameMenu
extends Control
## Small hideable debug button rows for the style frame (bottom of the panel mock). Buttons emit `action(id)`.

signal action(id: String)

const ROWS: Array = [
	["B0", "B1", "B2", "B3", "N40", "N100", "N165", "CLUMP"],
	["SCAN", "GLOW", "CAM", "LOOK", "ENV", "HIDE"],
]

var _buttons: Dictionary = {}
var _box: VBoxContainer = null
var _show: Button = null


func _ready() -> void:
	position = Vector2(12, 2236)
	size = Vector2(1056, 150)
	_box = VBoxContainer.new()
	_box.size = size
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)
	for row: Array in ROWS:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.custom_minimum_size = Vector2(1056, 68)
		_box.add_child(h)
		for id: String in row:
			var b := Button.new()
			b.text = id
			b.add_theme_font_size_override("font_size", 28)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.custom_minimum_size = Vector2(0, 68)
			b.pressed.connect(_on_pressed.bind(id))
			h.add_child(b)
			_buttons[id] = b
	_show = Button.new()
	_show.text = "."
	_show.modulate = Color(1, 1, 1, 0.25)
	_show.position = Vector2(1000, 2330)
	_show.size = Vector2(70, 60)
	_show.visible = false
	_show.pressed.connect(_on_pressed.bind("SHOW"))
	add_child(_show)
	_show.set_as_top_level(true)


func set_label(id: String, text: String) -> void:
	if _buttons.has(id):
		var v: Variant = _buttons[id]
		var b: Button = v
		b.text = text


func set_hidden(hidden: bool) -> void:
	_box.visible = not hidden
	_show.visible = hidden


func _on_pressed(id: String) -> void:
	action.emit(id)
