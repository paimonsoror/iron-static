class_name TitleButtons
extends Control
## The title's button rows in the V1 plate style (CONTINUE amber-active, then NEW GAME, SETTINGS). One Control draws
## all plates first and the labels second (the block costs 2 draw calls instead of 6). Rows are 160 px tall (touch
## target >= 148). The version number is not drawn here (a second font size costs a draw; Settings shows it). Emits
## `pressed(row_id)`.

signal pressed(row_id: String)

const FONT_SIZE: int = 54

var _rows: Array[String] = []
var _labels: Array[String] = []
var _down: int = -1
var _plate: StyleBoxTexture = null
var _plate_active: StyleBoxTexture = null
var _plate_pressed: StyleBoxTexture = null


func setup() -> void:
	_plate = UiKit.button()
	_plate_active = UiKit.button_active()
	_plate_pressed = UiKit.button_pressed()
	mouse_filter = Control.MOUSE_FILTER_STOP


## Sets the rows (ids from `TitleModel.rows`); the first row of a CONTINUE block is the amber one.
func set_rows(ids: Array[String]) -> void:
	_rows = ids
	_labels.clear()
	for id: String in ids:
		_labels.append(Strings.get_text(TitleModel.label_key(id)))
	_down = -1
	queue_redraw()


func rows() -> Array[String]:
	return _rows


## Rect of row `i` in this control's pixels.
func row_rect(i: int) -> Rect2:
	return Rect2(0.0, float(i) * (TitleModel.ROW_H + TitleModel.ROW_GAP), size.x, TitleModel.ROW_H)


func _row_at(p: Vector2) -> int:
	for i: int in _rows.size():
		if row_rect(i).has_point(p):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var i: int = _row_at(mb.position)
	if mb.pressed:
		_down = i
	else:
		var hit: bool = i >= 0 and i == _down
		_down = -1
		if hit:
			pressed.emit(_rows[i])
	queue_redraw()


func _draw() -> void:
	for i: int in _rows.size():
		var box: StyleBoxTexture = _plate_active if _rows[i] == TitleModel.ROW_CONTINUE else _plate
		if _down == i:
			box = _plate_pressed
		draw_style_box(box, row_rect(i))
	var font: Font = TitleArt.font_heading()
	for i: int in _rows.size():
		var r: Rect2 = row_rect(i)
		var active: bool = _rows[i] == TitleModel.ROW_CONTINUE
		var col: Color = Palette.AMBER_GLOW if active else Palette.TEXT
		var base_y: float = r.position.y + r.size.y * 0.5 + float(FONT_SIZE) * 0.34
		draw_string(
			font, Vector2(r.position.x, base_y), _labels[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, FONT_SIZE, col
		)
