class_name ColdOpen
extends MenuScreen
## The cold open (07 s3, M4-26): after NEW GAME on a fresh profile, three amber system lines (`RELAY 06 ONLINE`,
## `HOSTILE SWARM DETECTED`, `HOLD THE RELAY`) fade in on black, then Cinder fades in below them (`ColdOpenModel`
## timing). A tap anywhere or the back gesture skips it; it also ends by itself. Either way `finished` is emitted
## once, the FTUE `cold_open` beat is marked done in the profile, and the router starts run 1. Reduce motion shows
## everything at once and holds 3 s. Text is from `FtueScript.COLD_LINE_KEYS`.

signal finished

const LINE_FONT_PX: int = 64
const CINDER_H: float = 560.0
const SKIP_FONT_PX: int = 38

## Set true to force reduce motion (it is also read from `Game.visual.reduce_motion`).
var reduce_motion: bool = false

var _lines: Array[Label] = []
var _cinder: Control = null
var _skip_hint: Label = null
var _t: float = 0.0
var _done: bool = false


func _build() -> void:
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	for key: String in FtueScript.COLD_LINE_KEYS:
		var line: Label = label(key, &"LabelHeading", Palette.AMBER, LINE_FONT_PX)
		_lines.append(line)
		content.add_child(line)
	_cinder = Control.new()
	_cinder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cinder.custom_minimum_size = Vector2(0.0, CINDER_H)
	content.add_child(_cinder)
	var glow: TextureRect = _art("sil_vanguard_glow", true)
	var body: TextureRect = _art("sil_vanguard", false)
	_cinder.add_child(glow)
	_cinder.add_child(body)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skip_hint = label("ftue.cold.skip", &"LabelDim", Palette.TEXT_DIM, SKIP_FONT_PX)
	content.add_child(_skip_hint)
	_apply(0.0)
	set_process(false)


func enter() -> void:
	_t = 0.0
	_done = false
	_apply(0.0)
	set_process(true)


func leave() -> void:
	set_process(false)


func on_back() -> bool:
	skip()
	return true


## Ends the cold open now (tap, back, or the timer). Marks the beat done and emits `finished` once.
func skip() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	_mark_done()
	finished.emit()


func is_done() -> bool:
	return _done


## Seconds since the screen was shown.
func elapsed() -> float:
	return _t


## Advances the animation by `delta` seconds (the screen's `_process`; tests call it directly).
func advance(delta: float) -> void:
	if _done:
		return
	_t += delta
	_apply(_t)
	if ColdOpenModel.finished(_t, _reduced()):
		skip()


func line_alpha(index: int) -> float:
	return _lines[index].modulate.a


func cinder_alpha() -> float:
	return _cinder.modulate.a


func line_text(index: int) -> String:
	return _lines[index].text


func _process(delta: float) -> void:
	advance(delta)


func _gui_input(event: InputEvent) -> void:
	var tap: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		tap = mb.pressed
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		tap = st.pressed
	if tap:
		accept_event()
		skip()


func _reduced() -> bool:
	return reduce_motion or Game.visual.reduce_motion


func _apply(t: float) -> void:
	var red: bool = _reduced()
	for i: int in _lines.size():
		_lines[i].modulate.a = ColdOpenModel.line_alpha(i, t, red)
	_cinder.modulate.a = ColdOpenModel.cinder_alpha(t, red)


func _mark_done() -> void:
	if Game.saves == null:
		return
	var profile: PlayerProfile = Game.profile()
	var state: FtueState = FtueState.load_from(FtueScript.load_default(), profile)
	@warning_ignore("return_value_discarded")
	state.on_event(FtueScript.COLD_OPEN)
	@warning_ignore("return_value_discarded")
	state.complete(FtueScript.COLD_OPEN)
	state.store_to(profile)
	Game.saves.request_save()


## Cinder's silhouette sheet from the title art, centered in the Cinder slot (glow sheets draw additive, 2x).
func _art(sheet: String, glow: bool) -> TextureRect:
	var r := TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture = TitleArt.tex(sheet)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if glow:
		r.material = TitleArt.additive()
	return r
