class_name Hud
extends Control
## Minimal battle HUD (GDD 07 section 2.1: hud_wave, hud_timer_bar, hud_speed, hud_pause,
## hud_integrity_ring as a bar for M1) plus the bottom-44% placeholder panel.
## Base resolution 1080 wide: buttons are 150 px tall (about 57 dp at 1080 px = 411 dp).
## Signals only; the owner (M1-23) feeds values with refresh(world, now_s) at any rate, the
## HUD throttles label work to about 10 Hz and rewrites a label only when its integer changes.
## (impl) UI strings are constants here: data/strings_en.csv does not exist yet.

signal speed_changed(multiplier: int)
signal pause_toggled(paused: bool)

const SPEEDS: Array[int] = [1, 2]
const REFRESH_S: float = 0.1
const PANEL_TEXT: String = "UPGRADES: M2"
const BAR_BG := Color(Palette.GRID, 1.0)

var _speed_index: int = 0
var _paused: bool = false
var _last_refresh_s: float = -1.0
var _wave: int = -1
var _hp: int = -1
var _max_hp: int = -1
var _scrap: int = -1
var _data: int = -1

@onready var _wave_label: Label = %WaveLabel
@onready var _timer_bar: ProgressBar = %TimerBar
@onready var _speed_button: Button = %SpeedButton
@onready var _pause_button: Button = %PauseButton
@onready var _integrity_bar: ProgressBar = %IntegrityBar
@onready var _hp_label: Label = %HpLabel
@onready var _scrap_label: Label = %ScrapLabel
@onready var _data_label: Label = %DataLabel
@onready var _panel_label: Label = %PanelLabel
@onready var _panel: ColorRect = %Panel


func _ready() -> void:
	_panel.color = Palette.PANEL
	_panel_label.text = PANEL_TEXT
	_panel_label.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_style_label(_wave_label, Palette.AMBER)
	_style_label(_hp_label, Palette.TEXT)
	_style_label(_scrap_label, Palette.SCRAP)
	_style_label(_data_label, Palette.DATA)
	_style_bar(_timer_bar, Palette.AMBER_DIM)
	_style_bar(_integrity_bar, Palette.TEAL)
	_style_button(_speed_button)
	_style_button(_pause_button)
	_speed_button.pressed.connect(_on_speed_pressed)
	_pause_button.pressed.connect(_on_pause_pressed)
	_update_speed_text()
	_update_pause_text()


## Pulls values from the world; cheap to call every frame (throttled to REFRESH_S of `now_s`).
func refresh(world: SimWorld, now_s: float) -> void:
	if _last_refresh_s >= 0.0 and now_s - _last_refresh_s < REFRESH_S:
		return
	_last_refresh_s = now_s
	show_values(
		world.wave, world.wave_tick, world.cinder.hp, world.cinder.max_hp, world.run.scrap_earned, world.run.data_earned
	)


## Pure setter (also used by tests). Labels are rewritten only when the integer changes.
func show_values(wave: int, wave_tick: int, hp: float, max_hp: float, scrap: float, data: float) -> void:
	_timer_bar.value = float(wave_tick)
	var hp_i: int = ceili(maxf(hp, 0.0))
	var max_i: int = ceili(maxf(max_hp, 0.0))
	_integrity_bar.max_value = maxf(max_hp, 1.0)
	_integrity_bar.value = clampf(hp, 0.0, maxf(max_hp, 1.0))
	_style_integrity(hp / maxf(max_hp, 1.0))
	if wave != _wave:
		_wave = wave
		_wave_label.text = "WAVE %d" % wave
	if hp_i != _hp or max_i != _max_hp:
		_hp = hp_i
		_max_hp = max_i
		_hp_label.text = "%d / %d" % [hp_i, max_i]
	var scrap_i: int = floori(scrap)
	if scrap_i != _scrap:
		_scrap = scrap_i
		_scrap_label.text = "SCRAP %d" % scrap_i
	var data_i: int = floori(data)
	if data_i != _data:
		_data = data_i
		_data_label.text = "DATA %d" % data_i


## Current speed multiplier (1 or 2).
func speed() -> int:
	return SPEEDS[_speed_index]


func is_paused() -> bool:
	return _paused


## Sets the button state without emitting a signal.
func set_speed(multiplier: int) -> void:
	_speed_index = maxi(SPEEDS.find(multiplier), 0)
	_update_speed_text()


## Sets the button state without emitting a signal.
func set_paused(paused: bool) -> void:
	_paused = paused
	_update_pause_text()


func _on_speed_pressed() -> void:
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_update_speed_text()
	speed_changed.emit(SPEEDS[_speed_index])


func _on_pause_pressed() -> void:
	_paused = not _paused
	_update_pause_text()
	pause_toggled.emit(_paused)


func _update_speed_text() -> void:
	_speed_button.text = "%dx" % SPEEDS[_speed_index]


func _update_pause_text() -> void:
	_pause_button.text = "RESUME" if _paused else "PAUSE"


func _style_integrity(frac: float) -> void:
	var col: Color = _integrity_color(clampf(frac, 0.0, 1.0))
	var fill: StyleBoxFlat = _integrity_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null and fill.bg_color != col:
		fill.bg_color = col


func _style_label(label: Label, col: Color) -> void:
	label.add_theme_color_override("font_color", col)


func _style_bar(bar: ProgressBar, col: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = BAR_BG
	var fill := StyleBoxFlat.new()
	fill.bg_color = col
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)


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
	button.add_theme_color_override("font_pressed_color", Palette.TEXT)
	button.add_theme_color_override("font_hover_color", Palette.AMBER)
	button.add_theme_color_override("font_focus_color", Palette.AMBER)


## Teal (full) to amber (half) to red (quarter and below), same ramp as the Cinder ring.
static func _integrity_color(frac: float) -> Color:
	if frac >= 0.5:
		return Palette.AMBER.lerp(Palette.TEAL, (frac - 0.5) / 0.5)
	return Palette.CRITICAL.lerp(Palette.AMBER, clampf((frac - 0.25) / 0.25, 0.0, 1.0))
