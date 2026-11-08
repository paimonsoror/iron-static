class_name TitleFrameButtons
extends Control
## CONTINUE / NEW GAME / SETTINGS in the V1 ui_kit plate style (M3-25 style frame). One Control draws all three
## plates first and the labels second, so the whole block costs 2 draw calls instead of 6. 160 px tall touch rows
## (>= 148), 640 px wide, one-handed at the bottom. Emits `pressed(id)`.

signal pressed(id: String)

const IDS: Array[String] = ["continue", "new_game", "settings"]
const LABELS: Array[String] = ["CONTINUE", "NEW GAME", "SETTINGS"]
const ROW_H: float = 160.0
const GAP: float = 32.0
const WIDTH: float = 640.0
const FONT_SIZE: int = 54

var _hover: int = -1
var _down: int = -1
var _plate: StyleBoxTexture = null
var _plate_active: StyleBoxTexture = null
var _plate_pressed: StyleBoxTexture = null


func setup() -> void:
	custom_minimum_size = block_size()
	size = block_size()
	_plate = UiKit.button()
	_plate_active = UiKit.button_active()
	_plate_pressed = UiKit.button_pressed()
	mouse_filter = Control.MOUSE_FILTER_STOP


static func block_size() -> Vector2:
	return Vector2(WIDTH, ROW_H * 3.0 + GAP * 2.0)


func row_rect(i: int) -> Rect2:
	return Rect2(0.0, float(i) * (ROW_H + GAP), WIDTH, ROW_H)


func _row_at(p: Vector2) -> int:
	for i: int in IDS.size():
		if row_rect(i).has_point(p):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_hover = _row_at(mm.position)
		queue_redraw()
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		var i: int = _row_at(mb.position)
		if mb.pressed:
			_down = i
		else:
			if i >= 0 and i == _down:
				pressed.emit(IDS[i])
			_down = -1
		queue_redraw()


func _draw() -> void:
	for i: int in IDS.size():
		var box: StyleBoxTexture = _plate_active if i == 0 else _plate
		if _down == i:
			box = _plate_pressed
		draw_style_box(box, row_rect(i))
	var font: Font = TitleFrameArt.font_heading()
	for i: int in IDS.size():
		var r: Rect2 = row_rect(i)
		var col: Color = Palette.AMBER_GLOW if i == 0 else Palette.TEXT
		var base_y: float = r.position.y + r.size.y * 0.5 + float(FONT_SIZE) * 0.34
		draw_string(
			font, Vector2(r.position.x, base_y), LABELS[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, FONT_SIZE, col
		)
