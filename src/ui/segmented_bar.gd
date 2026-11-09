class_name SegmentedBar
extends Control
## Segmented bar inside a `ui_bar_frame` (art bible 7.1/7.2): N segments, `value` of `max_value`, optional teal -> amber
## -> red ramp (same ramp as the Cinder ring), bright head segment, tick row and a reserved dark number pocket on the
## right (a child Label sits in the pocket, never over lit segments). Redraws only when the lit count or color changes;
## a loss flashes the lost segments `CRITICAL` for FLASH_S (the process callback runs only during a flash).

const INSET: float = 6.0
const FLASH_S: float = 0.12
const EPS: float = 0.000001

var segments: int = 20:
	set(v):
		segments = maxi(v, 1)
		_refresh()
var max_value: float = 1.0:
	set(v):
		max_value = maxf(v, 0.0001)
		_refresh()
var value: float = 0.0:
	set(v):
		value = v
		_refresh()
## True: color follows the integrity ramp of the fill fraction; false: `color`.
var ramp: bool = false
var color: Color = Palette.AMBER
## True: partial segments count as lit (integrity); false: only fully elapsed ones (timer).
var ceil_fill: bool = true
var head_bright: bool = false
var ticks: bool = false
## Width of the dark number pocket at the right end (0 = none).
var pocket_px: float = 0.0
## Frame inset in px (thin bars use less so the segments stay tall).
var inset: float = INSET
## Loss flash on/off (off under reduce motion).
var animate: bool = true

var _filled: int = 0
var _color: Color = Palette.AMBER
var _flash_from: int = 0
var _flash_to: int = 0
var _flash_age: float = 0.0
var _frame: StyleBoxTexture = null
var _seg_on: Rect2 = Rect2()
var _seg_off: Rect2 = Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = UiKit.bar_frame()
	_seg_on = UiKit.segment_region(true)
	_seg_off = UiKit.segment_region(false)
	set_process(false)
	_filled = filled_count(value, max_value, segments, ceil_fill)
	_color = _target_color()
	queue_redraw()


## Number of lit segments for `value` / `max_value` (ceil: 51/100 of 20 -> 11, 0 -> 0, full -> `n`).
static func filled_count(v: float, max_v: float, n: int, ceil_mode: bool) -> int:
	var frac: float = clampf(v / maxf(max_v, 0.0001), 0.0, 1.0)
	var f: float = frac * float(n)
	if ceil_mode:
		return clampi(ceili(f - EPS), 0, n)
	return clampi(floori(f + EPS), 0, n)


## Teal (full) to amber (half) to red (quarter and below) in the active palette; same as `CinderView._integrity_color`.
static func ramp_color(frac: float) -> Color:
	var f: float = clampf(frac, 0.0, 1.0)
	var pal: PaletteSet = Palette.current()
	if f >= 0.5:
		return pal.amber.lerp(pal.teal, (f - 0.5) / 0.5)
	return pal.critical.lerp(pal.amber, clampf((f - 0.25) / 0.25, 0.0, 1.0))


## Flash strength 1 -> 0 over FLASH_S (0 at and after the end).
static func flash_strength(age_s: float) -> float:
	return clampf(1.0 - age_s / FLASH_S, 0.0, 1.0)


func lit_count() -> int:
	return _filled


func _target_color() -> Color:
	return ramp_color(value / max_value) if ramp else color


func _refresh() -> void:
	if _frame == null:
		return
	var f: int = filled_count(value, max_value, segments, ceil_fill)
	var col: Color = _target_color()
	if f == _filled and col == _color:
		return
	if f < _filled and animate:
		# A lost range extends a flash that is still running.
		if _flash_age < FLASH_S and _flash_to > _flash_from:
			_flash_from = mini(_flash_from, f)
			_flash_to = maxi(_flash_to, _filled)
		else:
			_flash_from = f
			_flash_to = _filled
		_flash_age = 0.0
		set_process(true)
	_filled = f
	_color = col
	queue_redraw()


func _process(delta: float) -> void:
	_flash_age += delta
	if _flash_age >= FLASH_S:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _frame == null:
		return
	draw_style_box(_frame, Rect2(Vector2.ZERO, size))
	var inner: Rect2 = Rect2(inset, inset, size.x - 2.0 * inset - pocket_px, size.y - 2.0 * inset)
	if pocket_px > 0.0:
		var pocket := Rect2(size.x - inset - pocket_px, inset, pocket_px, inner.size.y)
		draw_rect(pocket, Palette.PLATE_SHADOW)
		draw_rect(Rect2(pocket.position.x, pocket.position.y, 2.0, pocket.size.y), Palette.AMBER_DIM)
	var pitch: float = inner.size.x / float(segments)
	var flashing: bool = _flash_age < FLASH_S and _flash_to > _flash_from
	var sheet: Texture2D = UiKit.sheet()
	for i: int in segments:
		var r := Rect2(inner.position.x + pitch * float(i) + 1.0, inner.position.y, pitch - 2.0, inner.size.y)
		if i < _filled:
			var c: Color = _color
			if head_bright and i == _filled - 1:
				c = c.lightened(0.55)
			draw_texture_rect_region(sheet, r, _seg_on, c)
		else:
			draw_texture_rect_region(sheet, r, _seg_off, Color.WHITE)
			if flashing and i >= _flash_from and i < _flash_to:
				var a: float = flash_strength(_flash_age)
				draw_texture_rect_region(sheet, r, _seg_on, Color(Palette.current().critical, a))
	if ticks:
		_draw_ticks(sheet, inner)


func _draw_ticks(sheet: Texture2D, inner: Rect2) -> void:
	var minor: Rect2 = UiKit.region(UiKit.SLOT_TICK_MINOR)
	var major: Rect2 = UiKit.region(UiKit.SLOT_TICK_MAJOR)
	for k: int in 11:
		var x: float = inner.position.x + inner.size.x * float(k) / 10.0
		draw_texture_rect_region(sheet, Rect2(x - 1.0, size.y + 2.0, 2.0, 8.0), minor, Palette.AMBER_DIM)
	for q: int in 3:
		var xq: float = inner.position.x + inner.size.x * float(q + 1) * 0.25
		draw_texture_rect_region(sheet, Rect2(xq - 1.5, size.y + 2.0, 3.0, 16.0), major, Palette.AMBER_DIM)
