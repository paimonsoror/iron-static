class_name PauseButtons
extends Control
## The pause menu's three stacked plate buttons (RESUME amber-active, ABORT MISSION, EXIT GAME), drawn by one Control
## like `TitleButtons`. A button acts on a COMPLETED tap only: the press and the release land on the same row, the
## release is not cancelled and the finger stayed within `TAP_SLOP_PX`. Phone bug (gesture navigation): the back
## swipe from the screen edge first delivers a touch press to the app, then Android takes the gesture over and
## cancels the touch; that must never activate a button. A press outside every row activates nothing. Rows are
## 160 px tall (touch target >= 148). Emits `pressed(row_id)`.

signal pressed(row_id: String)

const ROW_RESUME: String = "resume"
const ROW_ABORT: String = "abort"
const ROW_EXIT: String = "exit"
const ROWS: Array[String] = [ROW_RESUME, ROW_ABORT, ROW_EXIT]
const ROW_H: float = 160.0
const ROW_GAP: float = 32.0
const FONT_SIZE: int = 54
## Largest finger travel (base px, ~23 dp) between press and release that still counts as a tap.
const TAP_SLOP_PX: float = 60.0
const NO_PRESS: Vector2 = Vector2(INF, INF)

var _labels: Array[String] = []
var _down: int = -1
var _press_pos: Vector2 = NO_PRESS
var _plate: StyleBoxTexture = null
var _plate_active: StyleBoxTexture = null
var _plate_pressed: StyleBoxTexture = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0.0, total_height())
	for id: String in ROWS:
		_labels.append(Strings.get_text("pause." + id))


func _ready() -> void:
	_plate = UiKit.button()
	_plate_active = UiKit.button_active()
	_plate_pressed = UiKit.button_pressed()


static func total_height() -> float:
	return float(ROWS.size()) * ROW_H + float(ROWS.size() - 1) * ROW_GAP


## Rect of row `i` in this control's pixels.
func row_rect(i: int) -> Rect2:
	return Rect2(0.0, float(i) * (ROW_H + ROW_GAP), size.x, ROW_H)


## Row index under `p`, -1 between or outside the rows.
func row_at(p: Vector2) -> int:
	for i: int in ROWS.size():
		if row_rect(i).has_point(p):
			return i
	return -1


## True when a press at `from` released at `to` is a tap: a press was seen, the release was not cancelled and the
## finger stayed within TAP_SLOP_PX.
static func is_tap(from: Vector2, to: Vector2, canceled: bool) -> bool:
	return from != NO_PRESS and not canceled and from.distance_to(to) <= TAP_SLOP_PX


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_down = -1  # a press that started before the menu appeared never activates
		_press_pos = NO_PRESS
		queue_redraw()


## Touch and the mouse emulated from it both arrive on a phone: the first release acts and clears the press, so the
## twin release is ignored.
func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if touch == null and mouse == null:
		return
	accept_event()
	var is_down: bool = touch.pressed if touch != null else mouse.pressed
	var pos: Vector2 = touch.position if touch != null else mouse.position
	var canceled: bool = touch.canceled if touch != null else mouse.canceled
	if is_down:
		_down = row_at(pos)
		_press_pos = pos
		queue_redraw()
		return
	var row: int = row_at(pos)
	var hit: bool = row >= 0 and row == _down and is_tap(_press_pos, pos, canceled)
	_down = -1
	_press_pos = NO_PRESS
	queue_redraw()
	if hit:
		pressed.emit(ROWS[row])


func _draw() -> void:
	if _plate == null:
		return
	for i: int in ROWS.size():
		var box: StyleBoxTexture = _plate_active if ROWS[i] == ROW_RESUME else _plate
		if _down == i:
			box = _plate_pressed
		draw_style_box(box, row_rect(i))
	var font: Font = TitleArt.font_heading()
	for i: int in ROWS.size():
		var r: Rect2 = row_rect(i)
		var col: Color = Palette.AMBER_GLOW if ROWS[i] == ROW_RESUME else Palette.TEXT
		var base_y: float = r.position.y + r.size.y * 0.5 + float(FONT_SIZE) * 0.34
		draw_string(
			font, Vector2(r.position.x, base_y), _labels[i], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, FONT_SIZE, col
		)
