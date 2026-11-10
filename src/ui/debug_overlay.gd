class_name DebugOverlay
extends Control
## Debug overlay (M1-24, GDD 08 section 1.8): on-device numbers and view-only band forcing.
## Off by default. Toggle: double tap (two presses within DOUBLE_TAP_MS) or a long press (LONG_PRESS_MS) inside
## the top-left CORNER_PX square. Both work with `adb shell input tap 40 40` twice (ideally in one shell
## command) or `adb shell input swipe 40 40 40 40 800`.
## Buttons (base 1080 px layout, top-left anchored so coordinates are identical on 1080x1920 and 1080x2400):
## B0..B3 force the displayed exposure band (view only, persists while the overlay is hidden), AUTO clears the
## override, LOAD restarts as the high-load scenario (wave 60, invulnerable; M1-25). Second row (y 420-510):
## BW0, BW12, BW100 set the in-memory best wave (M2-12); it applies from the next run start or redeploy.
## Third row (y 520-610, V1-03): HIGH, MID, LOW switch the VisualQuality tier; VSYNC toggles vsync (uncapped fps).
## Fourth row (y 620-710): D40, D100, D165 start a held load scenario (static crowd of about 40/100/165 enemies,
## sim paused when reached; render-cost bench), RUN resumes the sim, NOBF / NOHUD hide the battlefield / the HUD+panel
## (cost split: draws and fps with one layer off). Every press logs a [BENCH] line.
## [PERF] lines every PERF_PERIOD_S through Log.info while the overlay is shown or `force_perf` is true; with
## both off the overlay does no per-frame work at all. The text is rewritten at TEXT_REFRESH_S into a reused
## PackedStringArray (no per-frame allocation).

signal band_forced(band: int)
signal load_requested
signal best_wave_requested(wave: int)
signal scenario_requested(wave: int, hold: bool)
signal run_requested
signal layer_toggled(layer: int)

const CORNER_PX: float = 100.0
const DOUBLE_TAP_MS: int = 800
const LONG_PRESS_MS: int = 600
const PERF_PERIOD_S: float = 10.0
const TEXT_REFRESH_S: float = 0.25
const FPS_WINDOW: int = 60
const TICK_WINDOW: int = 120
const LINE_COUNT: int = 15
## Layers for layer_toggled.
const LAYER_BATTLEFIELD: int = 0
const LAYER_HUD: int = 1
## Held scenario load waves (alive enemies when reached: about 40, 100, 162; measured with sim_run, see docs/perf).
const SCENARIO_WAVES: Array[int] = [14, 19, 30]
const BEST_WAVES: Array[int] = [0, 12, 100]

## Set by the owner when the [PERF] log must run even with the overlay hidden (--debug-perf, load mode).
var force_perf: bool = false
## Set by the owner (main.gd) so the overlay can show the view's event-ring loss counter.
var battle_view: BattleView
## Set by the owner (main.gd): the tier switch buttons change it.
var visual: VisualSettings = VisualSettings.new()

## Touch gestures that open the overlay. Debug builds only: a release build can never show it (B1-07-A).
var gestures_enabled: bool = OS.is_debug_build()

var _controller: RunController
var _fps := DebugStats.new(FPS_WINDOW)
var _tick_ms := DebugStats.new(TICK_WINDOW)
var _render := RenderSampler.new()
var _render_ready: bool = false
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
@onready var _bw_buttons: Array[Button] = [%BW0, %BW12, %BW100]
@onready var _tier_buttons: Array[Button] = [%THigh, %TMid, %TLow]
@onready var _vsync_button: Button = %VsyncButton
@onready var _scn_buttons: Array[Button] = [%D40, %D100, %D165]
@onready var _run_button: Button = %RunButton
@onready var _layer_buttons: Array[Button] = [%NoBf, %NoHud]


func _ready() -> void:
	set_process_input(gestures_enabled)
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
	for i: int in _bw_buttons.size():
		_style_button(_bw_buttons[i])
		_bw_buttons[i].pressed.connect(_on_best_wave_pressed.bind(BEST_WAVES[i]))
	for i: int in _tier_buttons.size():
		_style_button(_tier_buttons[i])
		_tier_buttons[i].pressed.connect(_on_tier_pressed.bind(i))
	for i: int in _scn_buttons.size():
		_style_button(_scn_buttons[i])
		_scn_buttons[i].pressed.connect(_on_scenario_pressed.bind(SCENARIO_WAVES[i]))
	_style_button(_vsync_button)
	_style_button(_run_button)
	for i: int in _layer_buttons.size():
		_style_button(_layer_buttons[i])
		_layer_buttons[i].pressed.connect(_on_layer_pressed.bind(i))
	_vsync_button.pressed.connect(_on_vsync_pressed)
	_run_button.pressed.connect(_on_run_pressed)


func setup(controller: RunController) -> void:
	_controller = controller


## Formats the periodic perf line (parsed by M1-25: keep the exact shape).
## Optional fields are appended after `enemies=` only (the smoke parser ignores trailing text).
static func perf_line(
	fps_avg: float,
	fps_min: float,
	tick_ms: float,
	enemies: int,
	spawn_throttled: int = 0,
	events_lost: int = 0,
	extra: String = ""
) -> String:
	return (
		"[PERF] fps=%.1f min=%.1f tick_ms=%.2f enemies=%d thr=%d lost=%d%s"
		% [fps_avg, fps_min, tick_ms, enemies, spawn_throttled, events_lost, extra]
	)


func is_shown() -> bool:
	return visible


func toggle() -> void:
	if not gestures_enabled:
		return
	visible = not visible
	_since_text = TEXT_REFRESH_S


func _input(event: InputEvent) -> void:
	if not gestures_enabled:
		return
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
	if not _render_ready:
		_render_ready = true
		_render.setup(get_viewport())
	_fps.add(Engine.get_frames_per_second())
	_render.sample(delta)
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
				_controller.world.enemies.alive_count,
				_controller.world.run.spawn_throttled,
				_events_lost(),
				_render.take_suffix(visual.quality.tier_name())
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
	_lines[9] = "SPAWN_THROTTLED %d  EVENTS_LOST %d" % [w.run.spawn_throttled, _events_lost()]
	_lines[10] = (
		"CARRIED %d  DROP_CARRY %d  DROP_SLOTS %d" % [w.plan.carried, w.plan.dropped_carry, w.plan.dropped_slots]
	)
	_lines[11] = (
		"LOADING %d%%" % roundi(_controller.load_progress() * 100.0)
		if _controller.load_wave > 0
		else "v" + Game.VERSION
	)
	_lines[12] = "BEST WAVE %d (BW sets it; applies next run)" % _controller.best_wave_s1
	_lines[13] = (
		"DRAWS %d  OBJ %d  PRIMS %d"
		% [
			int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
			int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		]
	)
	_lines[14] = (
		"TEX %.1f  VID %.1f MB  TIER %s  VSYNC %s"
		% [
			Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / RenderSampler.MB,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / RenderSampler.MB,
			visual.quality.tier_name().to_upper(),
			"off" if DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED else "on",
		]
	)
	_stats_label.text = "\n".join(_lines)


func _events_lost() -> int:
	return battle_view.events_lost_total() if battle_view != null else 0


func _on_band_pressed(band: int) -> void:
	_forced_band = band
	_since_text = TEXT_REFRESH_S
	band_forced.emit(band)


func _on_best_wave_pressed(wave: int) -> void:
	_controller.best_wave_s1 = wave
	_since_text = TEXT_REFRESH_S
	best_wave_requested.emit(wave)


func _on_load_pressed() -> void:
	load_requested.emit()


func _on_tier_pressed(idx: int) -> void:
	visual.set_tier(idx as VisualQuality.Tier)
	_since_text = TEXT_REFRESH_S
	Log.info("[BENCH] tier=%s" % visual.quality.tier_name())


func _on_scenario_pressed(wave: int) -> void:
	scenario_requested.emit(wave, true)


func _on_layer_pressed(layer: int) -> void:
	layer_toggled.emit(layer)


func _on_run_pressed() -> void:
	run_requested.emit()
	Log.info("[BENCH] run resumed")


func _on_vsync_pressed() -> void:
	var off: bool = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED if off else DisplayServer.VSYNC_ENABLED)
	_since_text = TEXT_REFRESH_S
	Log.info("[BENCH] vsync=%s" % ("off" if off else "on"))


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
