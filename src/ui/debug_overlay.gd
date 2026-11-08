class_name DebugOverlay
extends Control
## Debug overlay (M1-24, GDD 08 section 1.8): on-device numbers and view-only band forcing.
## Off by default. Toggle: double tap (two presses within DOUBLE_TAP_MS) or a long press (LONG_PRESS_MS) inside
## the top-left CORNER_PX square. Both work with `adb shell input tap 40 40` twice (ideally in one shell
## command) or `adb shell input swipe 40 40 40 40 800`.
## Buttons (base 1080 px layout, top-left anchored so coordinates are identical on 1080x1920 and 1080x2400):
## B0..B3 force the displayed exposure band (view only, persists while the overlay is hidden), AUTO clears the
## override, LOAD restarts as the high-load scenario (wave 60, invulnerable; M1-25).
## [PERF] lines every PERF_PERIOD_S through Log.info while the overlay is shown or `force_perf` is true; with
## both off the overlay does no per-frame work at all. The text is rewritten at TEXT_REFRESH_S into a reused
## PackedStringArray (no per-frame allocation).

signal band_forced(band: int)
signal load_requested

const CORNER_PX: float = 100.0
const DOUBLE_TAP_MS: int = 800
const LONG_PRESS_MS: int = 600
const PERF_PERIOD_S: float = 10.0
const TEXT_REFRESH_S: float = 0.25
const FPS_WINDOW: int = 60
const TICK_WINDOW: int = 120
const LINE_COUNT: int = 10

## Set by the owner when the [PERF] log must run even with the overlay hidden (--debug-perf, load mode).
var force_perf: bool = false

var _controller: RunController
var _fps := DebugStats.new(FPS_WINDOW)
var _tick_ms := DebugStats.new(TICK_WINDOW)
var _lines := PackedStringArray()
var _since_perf: float = 0.0
var _since_text: float = TEXT_REFRESH_S
var _forced_band: int = -1
var _last_tap_ms: int = -1
var _press_ms: int = -1

@onready var _stats_label: Label = %StatsLabel
@onready var _band_buttons: Array[Button] = [%B0, %B1, %B2, %B3]
@onready var _auto_button: Button = %AutoButton
@onready var _load_button: Button = %LoadButton


func _ready() -> void:
	if _lines.resize(LINE_COUNT) != OK:
		push_error("DebugOverlay: resize failed")
	_stats_label.add_theme_color_override("font_color", Palette.AMBER_GLOW)
	for i: int in _band_buttons.size():
		_style_button(_band_buttons[i])
		_band_buttons[i].pressed.connect(_on_band_pressed.bind(i))
	_style_button(_auto_button)
	_style_button(_load_button)
	_auto_button.pressed.connect(_on_band_pressed.bind(-1))
	_load_button.pressed.connect(_on_load_pressed)


func setup(controller: RunController) -> void:
	_controller = controller


## Formats the periodic perf line (parsed by M1-25: keep the exact shape).
static func perf_line(fps_avg: float, fps_min: float, tick_ms: float, enemies: int) -> String:
	return "[PERF] fps=%.1f min=%.1f tick_ms=%.2f enemies=%d" % [fps_avg, fps_min, tick_ms, enemies]


func is_shown() -> bool:
	return visible


func toggle() -> void:
	visible = not visible
	_since_text = TEXT_REFRESH_S


func _input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch == null:
		return
	if touch.pressed:
		_on_press(touch.position, Time.get_ticks_msec())
	else:
		_on_release(Time.get_ticks_msec())


func _on_press(pos: Vector2, now_ms: int) -> void:
	_press_ms = -1
	if pos.x > CORNER_PX or pos.y > CORNER_PX:
		return
	if _last_tap_ms >= 0 and now_ms - _last_tap_ms <= DOUBLE_TAP_MS:
		_last_tap_ms = -1
		toggle()
		return
	_last_tap_ms = now_ms
	_press_ms = now_ms


func _on_release(now_ms: int) -> void:
	if _press_ms >= 0 and now_ms - _press_ms >= LONG_PRESS_MS:
		_last_tap_ms = -1
		toggle()
	_press_ms = -1


func _process(delta: float) -> void:
	if not visible and not force_perf:
		return
	if _controller == null or _controller.world == null:
		return
	_fps.add(Engine.get_frames_per_second())
	if _controller.last_ticks > 0:
		_tick_ms.add(float(_controller.last_usec) / 1000.0 / float(_controller.last_ticks))
	_since_perf += delta
	if _since_perf >= PERF_PERIOD_S:
		_since_perf = 0.0
		Log.info(
			perf_line(
				_fps.period_average(),
				_fps.period_min(),
				_tick_ms.period_average(),
				_controller.world.enemies.alive_count
			)
		)
		_fps.reset_period()
		_tick_ms.reset_period()
	_since_text += delta
	if visible and _since_text >= TEXT_REFRESH_S:
		_since_text = 0.0
		_refresh_text(_controller.world)


func _refresh_text(w: SimWorld) -> void:
	var t: SimTuning = w.config.tuning
	var g_hp: float = Curves.g_growth(w.level_hp, t.g_hp_1, t.g_hp_2, t.g_hp_3, t.phase_1_end, t.phase_2_end)
	var skitter_hp: float = t.hp0 * g_hp * w.config.enemies[0].hp_mult
	var n_w: int = Curves.slots_for_wave(w.wave, t.n_base, t.n_coef, t.n_exp, t.n_cap)
	var band_text: String = "auto" if _forced_band < 0 else "B%d" % _forced_band
	_lines[0] = "FPS %d (min %d)" % [roundi(_fps.average()), roundi(_fps.minimum())]
	_lines[1] = "SIM %.2f ms/tick" % _tick_ms.average()
	_lines[2] = "ENEMIES %d  BOLTS %d" % [w.enemies.alive_count, w.projectiles.alive_count]
	_lines[3] = "WAVE %d  LEVEL_HP %d" % [w.wave, w.level_hp]
	_lines[4] = "G_HP %.3f  SKITTER HP %.3f" % [g_hp, skitter_hp]
	_lines[5] = "N(W) %d" % n_w
	_lines[6] = (
		"TICKS/FRAME %d  THROTTLED %s" % [_controller.last_ticks, "YES" if _controller.driver.throttled else "no"]
	)
	_lines[7] = (
		"SPEED %dx%s  SEED %d" % [_controller.speed, " PAUSED" if _controller.paused else "", _controller.seed_value]
	)
	_lines[8] = "BAND %d  VIEW %s" % [w.cinder.band, band_text]
	_lines[9] = (
		"LOADING %d%%" % roundi(_controller.load_progress() * 100.0)
		if _controller.load_wave > 0
		else "v" + Game.VERSION
	)
	_stats_label.text = "\n".join(_lines)


func _on_band_pressed(band: int) -> void:
	_forced_band = band
	_since_text = TEXT_REFRESH_S
	band_forced.emit(band)


func _on_load_pressed() -> void:
	load_requested.emit()


func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.PANEL
	normal.border_color = Palette.AMBER_DIM
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(8)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Palette.AMBER_DIM
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Palette.AMBER)
	button.add_theme_color_override("font_hover_color", Palette.AMBER)
	button.add_theme_color_override("font_pressed_color", Palette.TEXT)
	button.add_theme_color_override("font_focus_color", Palette.AMBER)
