class_name WaveBanner
extends Control
## Wave banner (art bible 7.2, `vfx_wave_banner_glitch`): a chamfered plate slides in from the left in SLIDE_IN_S, a
## two-step horizontal jitter of the text runs for GLITCH_S, it holds HOLD_S and leaves in SLIDE_OUT_S. Boss waves use
## the larger plate with hazard stripes, "WARNING" in amber and a sub line. Reduce motion: no slide or jitter, the plate
## just appears for HOLD_S. Never takes input. Text comes from the caller (Strings keys); the node is hidden when idle.

const SLIDE_IN_S: float = 0.35
const GLITCH_S: float = 0.08
const HOLD_S: float = 0.8
const SLIDE_OUT_S: float = 0.25
const GLITCH_PX: float = 14.0
const PLATE_SIZE: Vector2 = Vector2(600.0, 112.0)
const BOSS_PLATE_SIZE: Vector2 = Vector2(780.0, 212.0)
const STRIPE_H: float = 16.0
const FALLBACK_W: float = 1080.0

var _plate: Panel = null
var _box: VBoxContainer = null
var _title: Label = null
var _sub: Label = null
var _stripe_top: Panel = null
var _stripe_bottom: Panel = null
var _tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build()
	visible = false


## Total on-screen time of one banner.
static func total_s(reduce_motion: bool) -> float:
	if reduce_motion:
		return HOLD_S
	return SLIDE_IN_S + GLITCH_S + HOLD_S + SLIDE_OUT_S


## Starts (or restarts) the banner. `sub` is only shown for `boss`.
func play(title: String, boss: bool, sub: String = "", reduce_motion: bool = false) -> void:
	if _plate == null:
		_build()
	if _tween != null:
		_tween.kill()
	var psize: Vector2 = BOSS_PLATE_SIZE if boss else PLATE_SIZE
	_plate.size = psize
	custom_minimum_size.y = psize.y
	_plate.add_theme_stylebox_override("panel", UiKit.plate() if boss else UiKit.plate_active())
	_title.text = title
	_title.add_theme_color_override("font_color", Palette.AMBER if boss else Palette.TEXT)
	_sub.text = sub
	_sub.visible = boss
	_stripe_top.visible = boss
	_stripe_bottom.visible = boss
	_stripe_top.size = Vector2(psize.x - 56.0, STRIPE_H)
	_stripe_bottom.size = _stripe_top.size
	_stripe_top.position = Vector2(28.0, 14.0)
	_stripe_bottom.position = Vector2(28.0, psize.y - 14.0 - STRIPE_H)
	_box.position = Vector2(0.0, 34.0 if boss else 0.0)
	_box.size = Vector2(psize.x, psize.y - (68.0 if boss else 0.0))
	_set_glitch(0)
	var w: float = size.x if size.x > 0.0 else FALLBACK_W
	var rest: float = (w - psize.x) * 0.5
	visible = true
	_tween = create_tween()
	if reduce_motion:
		_plate.position = Vector2(rest, 0.0)
		_tween.tween_interval(HOLD_S)
	else:
		_plate.position = Vector2(-psize.x, 0.0)
		_tween.tween_property(_plate, "position:x", rest, SLIDE_IN_S).set_trans(Tween.TRANS_CUBIC).set_ease(
			Tween.EASE_OUT
		)
		_tween.tween_callback(_set_glitch.bind(1))
		_tween.tween_interval(GLITCH_S * 0.5)
		_tween.tween_callback(_set_glitch.bind(-1))
		_tween.tween_interval(GLITCH_S * 0.5)
		_tween.tween_callback(_set_glitch.bind(0))
		_tween.tween_interval(HOLD_S)
		_tween.tween_property(_plate, "position:x", w, SLIDE_OUT_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_callback(_finish)


func is_playing() -> bool:
	return visible


## Global y of the bottom edge of the plate while a banner is up (the tier-up banner sits below it), else 0.
func occupied_bottom() -> float:
	if not visible or _plate == null:
		return 0.0
	return global_position.y + _plate.size.y


func stop() -> void:
	if _tween != null:
		_tween.kill()
	_finish()


func _finish() -> void:
	visible = false


func _set_glitch(dir: int) -> void:
	_title.position.x = GLITCH_PX * float(dir)
	_sub.position.x = -GLITCH_PX * float(dir) * 0.5


func _build() -> void:
	_plate = Panel.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plate)
	_stripe_top = _stripe()
	_stripe_bottom = _stripe()
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_box)
	_title = Label.new()
	_title.theme_type_variation = ThemeBuilder.VAR_LABEL_HEADING
	_title.add_theme_font_size_override("font_size", 72)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_title)
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_color_override("font_color", Palette.TEXT)
	_sub.add_theme_font_size_override("font_size", 44)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_sub)


func _stripe() -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiKit.hazard_stripe())
	_plate.add_child(p)
	return p
