class_name SettingsSlider
extends Control
## Horizontal 0..1 slider in the HUD bar style (M3-18). Hit area >= 148 px tall. Only a horizontal-dominant drag
## changes the value, so a vertical scroll over the list never moves it; a tap does nothing. Events are not
## accepted until a horizontal drag locks, so the list's scroll still gets vertical drags.

signal value_changed(value: float)
## Emitted when a value drag ends (`changed`: it moved the value); the screen plays the preview sample.
signal drag_released(changed: bool)

const MIN_HEIGHT: float = 148.0
const DEADZONE_PX: float = 16.0
## A drag locks to the slider when |dx| exceeds |dy| times this.
const HORIZONTAL_RATIO: float = 1.5
const SEGMENTS: int = 20
const BAR_H: float = 64.0
const PAD: float = 12.0

var value: float = 0.0
var step: float = SettingsModel.VOLUME_STEP
var _press: Vector2 = Vector2.ZERO
var _pressed: bool = false
var _locked: bool = false
var _changed: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(0.0, MIN_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE


func set_value_silent(v: float) -> void:
	value = clampf(v, 0.0, 1.0)
	queue_redraw()


func is_dragging() -> bool:
	return _locked


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pressed = true
			_locked = false
			_changed = false
			_press = mb.position
		elif _pressed:
			var was_locked: bool = _locked
			_pressed = false
			_locked = false
			if was_locked:
				accept_event()
				drag_released.emit(_changed)
	elif event is InputEventMouseMotion and _pressed:
		var mm: InputEventMouseMotion = event
		if not _locked:
			var d: Vector2 = mm.position - _press
			if d.length() < DEADZONE_PX:
				return
			if absf(d.x) > absf(d.y) * HORIZONTAL_RATIO:
				_locked = true
			else:
				_pressed = false  # a vertical drag belongs to the scroll list
				return
		accept_event()
		_set_from_x(mm.position.x)
	elif event is InputEventScreenDrag and _locked:
		accept_event()


func _set_from_x(x: float) -> void:
	var span: float = maxf(size.x - 2.0 * PAD, 1.0)
	var v: float = clampf((x - PAD) / span, 0.0, 1.0)
	v = clampf(snappedf(v, step), 0.0, 1.0)
	if is_equal_approx(v, value):
		return
	value = v
	_changed = true
	queue_redraw()
	value_changed.emit(value)


func _draw() -> void:
	var bar := Rect2(PAD, (size.y - BAR_H) * 0.5, maxf(size.x - 2.0 * PAD, 1.0), BAR_H)
	draw_style_box(UiKit.bar_frame(), bar)
	var inner: Rect2 = bar.grow(-8.0)
	var seg_w: float = inner.size.x / float(SEGMENTS)
	var lit: int = roundi(value * float(SEGMENTS))
	for i: int in SEGMENTS:
		var r := Rect2(inner.position.x + seg_w * float(i) + 1.0, inner.position.y, seg_w - 2.0, inner.size.y)
		var tint: Color = Palette.AMBER if i < lit else Color.WHITE
		draw_texture_rect_region(UiKit.sheet(), r, UiKit.segment_region(i < lit), tint)
	var tx: float = bar.position.x + 8.0 + (bar.size.x - 16.0) * value
	draw_rect(Rect2(tx - 6.0, bar.position.y - 14.0, 12.0, bar.size.y + 28.0), Palette.AMBER_GLOW)
