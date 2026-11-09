class_name TierBanner
extends Control
## The tier-up banner of the battle (VT-5, docs/design/12 s5, mock `ut_tier_up.jpg`): a dark plate with amber top and
## bottom lines and corner brackets, the title (`LASER MK II`, Oxanium) and a small teal line (`BEAM OUTPUT TIER UP`).
## Slides down SLIDE_S, holds (HOLD_MK2_S for MK II, HOLD_S otherwise), fades FADE_S. `flat` (reduce motion or LOW
## quality): no slide, the plate is just there and fades. One banner at a time: the director sequences the moments,
## `play_moment` restarts if one is still up. Never takes input; hidden when idle. Timings live in `TierUpDirector`.

const PLATE_SIZE: Vector2 = Vector2(640.0, 150.0)
const SLIDE_PX: float = 44.0
const LINE_H: float = 4.0
const BRACKET: Vector2 = Vector2(10.0, 120.0)
const TOP_GAP: float = 24.0  # plate top below the HUD bar (the field top), M4-27 F8
const WAVE_GAP: float = 20.0  # gap under a wave or boss banner that is up at the same time
## Priority with the wave banner (M4-27 F8): both may be up at once. The tier-up banner sits directly under the HUD bar
## and drops below the wave banner's plate while one is up, so neither hides the other.

## Returns the global y of the bottom of the wave banner plate while it is up, else 0 (set by the host).
var avoid_bottom: Callable = Callable()

var _plate: Control = null
var _title: Label = null
var _sub: Label = null
var _tween: Tween = null
var _field: Rect2 = Rect2(0.0, 250.0, 1080.0, 900.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	set_process(false)


## The open field in viewport px (below the HUD bar, above the panel); the plate sits near its top, above Cinder.
func set_field_rect(rect: Rect2) -> void:
	_field = rect
	_place()


func play_moment(moment: TierUpMoment) -> void:
	play(moment.title(), moment.sub(), moment.tier, moment.flat)


func play(title: String, sub: String, tier: int, flat: bool) -> void:
	if _plate == null:
		_build()
	if _tween != null:
		_tween.kill()
	_title.text = title
	_sub.text = sub
	_place()
	visible = true
	set_process(true)
	_plate.modulate.a = 1.0 if flat else 0.0
	_plate.position.y = 0.0 if flat else -SLIDE_PX
	_tween = create_tween()
	if not flat:
		_tween.set_parallel(true)
		_tween.tween_property(_plate, "position:y", 0.0, TierUpDirector.SLIDE_S).set_trans(Tween.TRANS_CUBIC).set_ease(
			Tween.EASE_OUT
		)
		_tween.tween_property(_plate, "modulate:a", 1.0, TierUpDirector.SLIDE_S)
		_tween.set_parallel(false)
		_tween.tween_interval(TierUpDirector.hold_s(tier))
	else:
		_tween.tween_interval(TierUpDirector.hold_s(tier))
	_tween.tween_property(_plate, "modulate:a", 0.0, TierUpDirector.FADE_S)
	_tween.tween_callback(_finish)


func is_playing() -> bool:
	return visible


func title_text() -> String:
	return _title.text if _title != null else ""


func sub_text() -> String:
	return _sub.text if _sub != null else ""


## Drops the banner at once (a new run, leaving the battle).
func cancel() -> void:
	if _tween != null:
		_tween.kill()
	_finish()


func _finish() -> void:
	visible = false
	set_process(false)


func _process(_delta: float) -> void:  # gdlint: ignore=unused-argument
	# A wave banner that starts while this one is up pushes it down (never back up mid-banner).
	var y: float = top_y(_field, _avoid())
	if y > position.y:
		position.y = y


## Top of the plate: just under the HUD bar (field top), or under a wave banner whose plate ends at `avoid_y`.
static func top_y(field: Rect2, avoid_y: float) -> float:
	var y: float = field.position.y + TOP_GAP
	if avoid_y > 0.0:
		y = maxf(y, avoid_y + WAVE_GAP)
	return y


func _avoid() -> float:
	return avoid_bottom.call() if avoid_bottom.is_valid() else 0.0


func _place() -> void:
	size = PLATE_SIZE
	position = Vector2(_field.position.x + (_field.size.x - PLATE_SIZE.x) * 0.5, top_y(_field, _avoid()))


func _build() -> void:
	_plate = Control.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.size = PLATE_SIZE
	add_child(_plate)
	_plate.add_child(_rect(Vector2.ZERO, PLATE_SIZE, Color(0.05, 0.065, 0.09, 0.92)))
	_plate.add_child(_rect(Vector2.ZERO, Vector2(PLATE_SIZE.x, LINE_H), Palette.AMBER))
	_plate.add_child(_rect(Vector2(0.0, PLATE_SIZE.y - LINE_H), Vector2(PLATE_SIZE.x, LINE_H), Palette.AMBER_DIM))
	var by: float = (PLATE_SIZE.y - BRACKET.y) * 0.5
	_plate.add_child(_rect(Vector2(-BRACKET.x - 4.0, by), BRACKET, Palette.AMBER))
	_plate.add_child(_rect(Vector2(PLATE_SIZE.x + 4.0, by), BRACKET, Palette.AMBER))
	_title = Label.new()
	_title.theme_type_variation = ThemeBuilder.VAR_LABEL_HEADING
	_title.add_theme_color_override("font_color", Palette.AMBER_GLOW)
	_title.add_theme_font_size_override("font_size", ThemeBuilder.FONT_SIZE_HEADING)
	_title.position = Vector2(0.0, 18.0)
	_title.size = Vector2(PLATE_SIZE.x, 64.0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_title)
	_sub = Label.new()
	_sub.theme_type_variation = ThemeBuilder.VAR_LABEL_NUMBER
	_sub.add_theme_font_size_override("font_size", 32)
	_sub.add_theme_color_override("font_color", Palette.TEAL)
	_sub.position = Vector2(0.0, 88.0)
	_sub.size = Vector2(PLATE_SIZE.x, 44.0)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.add_child(_sub)
	_place()


func _rect(pos: Vector2, rect_size: Vector2, color: Color) -> ColorRect:
	var r: ColorRect = ColorRect.new()
	r.position = pos
	r.size = rect_size
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
