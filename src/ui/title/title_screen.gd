class_name TitleScreen
extends MenuScreen
## The title screen (M3-28): smoky wasteland parallax (`TitleFx`, 1-3 smoke layers by quality tier, embers, flare),
## the selected frame as the hero on the ridge, the shimmering logo, and the button rows (`TitleButtons`:
## CONTINUE only when the profile has progress, NEW GAME, SETTINGS). Signals are final; routing is the router's job
## (M3-30). Back opens the QUIT? confirm (`on_back` consumes it; the router quits on YES). Reduce motion freezes
## drift, shimmer, flare and embers. A hidden title does not process (router: `process_mode` disabled; `leave`).

signal continue_pressed
signal new_game_pressed
signal settings_pressed
signal quit_confirmed

var _fx: TitleFx
var _logo: TitleLogo
var _buttons: TitleButtons
var _overlay: ColorRect
var _fade: ColorRect
var _quit_box: VBoxContainer
var _defs: Array[FrameDef] = []
var _t: float = 0.0
var _fade_t: float = TitleModel.FADE_S
var _shown_once: bool = false


func _build() -> void:
	# the screen draws its own art: drop the base's flat background and put the stage first
	var bg: Node = get_child(0)
	remove_child(bg)
	bg.queue_free()
	_fx = TitleFx.new()
	add_child(_fx)
	move_child(_fx, 0)
	_fx.build()
	_build_quit_box()
	_buttons = TitleButtons.new()
	add_child(_buttons)
	_buttons.setup()
	_buttons.pressed.connect(_on_row)
	_logo = TitleLogo.new()
	add_child(_logo)
	_logo.setup()
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var om := ShaderMaterial.new()
	om.shader = load(TitleArt.SHADER_OVERLAY) as Shader
	_overlay.material = om
	add_child(_overlay)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.visible = false
	add_child(_fade)
	show_state(VisualQuality.Tier.HIGH, false, false, "vanguard")


func _build_quit_box() -> void:
	_quit_box = VBoxContainer.new()
	_quit_box.add_theme_constant_override("separation", SEPARATION)
	_quit_box.add_child(label("title.quit_title", &"LabelHeading", Palette.AMBER, 80))
	_quit_box.add_child(make_button("title.quit_yes", _on_quit_yes))
	_quit_box.add_child(make_button("title.quit_no", _close_quit))
	_quit_box.visible = false
	content.add_child(_quit_box)


## Applies the view state: quality tier, reduce motion, whether CONTINUE shows, and the hero frame id.
func show_state(tier: VisualQuality.Tier, motion_off: bool, progress: bool, frame_id: String) -> void:
	_fx.reduce_motion = motion_off
	_logo.reduce_motion = motion_off
	_fx.set_tier(tier)
	_fx.set_frame(frame_id)
	_overlay.visible = TitleModel.scanlines_enabled(tier, motion_off)
	_buttons.set_rows(TitleModel.rows(progress))
	_layout()


func enter() -> void:
	var profile: PlayerProfile = Game.profile() if Game.saves != null else null
	if _defs.is_empty():
		_defs = FrameRules.load_defs()
	var frame_id: String = "vanguard"
	if profile != null:
		frame_id = TitleModel.hero_frame(profile, _defs)
	show_state(Game.visual.quality.tier, Game.visual.reduce_motion, TitleModel.has_progress(profile), frame_id)
	_close_quit()
	if not _shown_once:
		_shown_once = true
		_fade_t = 0.0
	set_process(true)
	AudioHooks.director().start_menu_audio()


func leave() -> void:
	set_process(false)


func on_back() -> bool:
	if _quit_box.visible:
		_close_quit()
	else:
		_quit_box.visible = true
		_buttons.visible = false
	return true


func _layout() -> void:
	super._layout()
	if _buttons == null:
		return
	var col: Rect2 = column_rect()
	var r: Rect2 = TitleModel.buttons_rect(col, _buttons.rows().size())
	_buttons.position = r.position
	_buttons.size = r.size
	_logo.position = Vector2(col.position.x + col.size.x * 0.5, TitleModel.logo_center_y(size, _safe.y))
	_fx.layout(size)
	_overlay.size = size
	(_overlay.material as ShaderMaterial).set_shader_parameter("rect_px", size)
	_fade.size = size


## Advances the view clock by `dt` seconds (the screen's `_process`; tests call it directly).
func advance(dt: float) -> void:
	_t += dt
	_fade_t = minf(_fade_t + dt, TitleModel.FADE_S)
	var a: float = 1.0 - smoothstep(0.0, 1.0, _fade_t / TitleModel.FADE_S)
	_fade.color = Color(0.0, 0.0, 0.0, a)
	_fade.visible = a > 0.0
	_fx.tick(_t, dt)
	_logo.tick(_t, dt)


func _process(delta: float) -> void:
	advance(delta)


func fx() -> TitleFx:
	return _fx


func logo() -> TitleLogo:
	return _logo


func buttons() -> TitleButtons:
	return _buttons


func quit_box_visible() -> bool:
	return _quit_box.visible


func fade_alpha() -> float:
	return _fade.color.a if _fade.visible else 0.0


func scanlines_visible() -> bool:
	return _overlay.visible


func _on_row(row_id: String) -> void:
	AudioHooks.tap()
	match row_id:
		TitleModel.ROW_CONTINUE:
			continue_pressed.emit()
		TitleModel.ROW_NEW_GAME:
			new_game_pressed.emit()
		TitleModel.ROW_SETTINGS:
			settings_pressed.emit()


func _on_quit_yes() -> void:
	AudioHooks.tap()
	quit_confirmed.emit()


func _close_quit() -> void:
	_quit_box.visible = false
	_buttons.visible = true
