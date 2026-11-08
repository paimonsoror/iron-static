class_name RowFx
extends Control
## Overlay of one `UpgradeRow` (V1-17): gold milestone ring with a sweeping highlight, the expansion on a milestone
## purchase, the amber pulse around an affordable cost button and the 120 ms purchase flash. Draws only; the row sets
## the flags. `_process` runs only while something moves and the node is visible (hidden tab rows cost nothing);
## under reduce motion the ring and pulse are steady. `RingAnim` holds the curves; nothing allocates per frame.

const RING_WIDTH: float = 4.0
const COMET_RADIUS: float = 9.0
const COMET_TRAIL: int = 3
const COMET_STEP: float = 0.012
const PULSE_MIN: float = 0.25
const PULSE_MAX: float = 0.85

var ring: bool = false:
	set(v):
		ring = v
		_refresh()
var pulse: bool = false:
	set(v):
		pulse = v
		_refresh()
var reduced: bool = false:
	set(v):
		reduced = v
		_refresh()
## Cost button the pulse and flash outline (row-local rect is derived from its global position).
var button: Control = null

var _t: float = 0.0
var _expand_age: float = -1.0
var _flash_age: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func play_expand() -> void:
	if reduced:
		return
	_expand_age = 0.0
	_refresh()


func play_flash() -> void:
	_flash_age = 0.0
	_refresh()


func is_animating() -> bool:
	return is_processing()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_refresh()


func _wants_process() -> bool:
	var moving: bool = (ring or pulse) and not reduced
	return is_visible_in_tree() and (moving or _expand_age >= 0.0 or _flash_age >= 0.0)


func _refresh() -> void:
	if not is_inside_tree():
		return
	set_process(_wants_process())
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _expand_age >= 0.0:
		_expand_age += delta
		if _expand_age >= RingAnim.EXPAND_S:
			_expand_age = -1.0
	if _flash_age >= 0.0:
		_flash_age += delta
		if _flash_age >= RingAnim.FLASH_S:
			_flash_age = -1.0
	if not _wants_process():
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if ring:
		_draw_ring()
	if _expand_age >= 0.0:
		var p: float = RingAnim.expand_progress(_expand_age)
		var inset: float = lerpf(20.0, 0.0, p)
		var c: Color = Palette.AMBER_GLOW
		c.a = 1.0 - p
		draw_rect(Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0), c, false, 6.0)
	var br: Rect2 = _button_rect()
	if pulse and br.size.x > 0.0:
		var a: float = PULSE_MAX if reduced else lerpf(PULSE_MIN, PULSE_MAX, RingAnim.pulse(_t))
		var pc: Color = Palette.AMBER_GLOW
		pc.a = a
		draw_rect(br.grow(-3.0), pc, false, 3.0)
	if _flash_age >= 0.0 and br.size.x > 0.0:
		var fc := Color(1.0, 0.9, 0.6, 0.35 * (1.0 - _flash_age / RingAnim.FLASH_S))
		draw_rect(br, fc, true)


func _draw_ring() -> void:
	var gold: Color = Palette.AMBER_GLOW
	var inner: Rect2 = Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
	gold.a = 0.75
	draw_rect(inner, gold, false, RING_WIDTH)
	if reduced:
		return
	var u: float = RingAnim.sweep(_t)
	for k: int in COMET_TRAIL + 1:
		var c: Color = Color.WHITE
		c.a = 1.0 - float(k) / float(COMET_TRAIL + 1)
		var pt: Vector2 = inner.position + RingAnim.perimeter_point(inner.size, u - float(k) * COMET_STEP)
		draw_circle(pt, COMET_RADIUS * (1.0 - 0.18 * float(k)), c)


func _button_rect() -> Rect2:
	if button == null:
		return Rect2()
	return Rect2(button.global_position - global_position, button.size)
