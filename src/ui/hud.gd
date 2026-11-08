class_name Hud
extends Control
## Battle HUD (GDD 07 section 2.1: hud_wave, hud_timer_bar, hud_speed, hud_pause, hud_integrity_ring as a bar,
## hud_scrap amber, hud_data_run blue) plus the bottom-44% `UpgradePanel` (M2-10).
## Base resolution 1080 wide: buttons are 150 px tall (about 57 dp at 1080 px = 411 dp).
## Signals only; the owner feeds values with refresh(world, now_s) at any rate. Counter text comes from `HudModel`
## (10 Hz throttle, `NumberFormat`); a label is rewritten only when its text changed. The panel is bound to the
## world on the first refresh of each new world; its `buy_requested` is re-emitted here for M2-12.

signal speed_changed(multiplier: int)
signal pause_toggled(paused: bool)
signal buy_requested(upgrade_index: int, count: int)

const SPEEDS: Array[int] = [1, 2]
const BAR_BG := Color(Palette.GRID, 1.0)

var _speed_index: int = 0
var _paused: bool = false
var _model: HudModel = HudModel.new()

@onready var _wave_label: Label = %WaveLabel
@onready var _timer_bar: ProgressBar = %TimerBar
@onready var _speed_button: Button = %SpeedButton
@onready var _pause_button: Button = %PauseButton
@onready var _integrity_bar: ProgressBar = %IntegrityBar
@onready var _hp_label: Label = %HpLabel
@onready var _scrap_label: Label = %ScrapLabel
@onready var _data_label: Label = %DataLabel
@onready var _panel: UpgradePanel = %UpgradePanel


func _ready() -> void:
	theme = ThemeBuilder.shared()
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
	_panel.buy_requested.connect(_on_buy_requested)
	_update_speed_text()
	_update_pause_text()


## The upgrade panel (for M2-12 wiring and tests).
func upgrade_panel() -> UpgradePanel:
	return _panel


## Pulls values from the world; cheap to call every frame (throttled to HudModel.REFRESH_S of `now_s`).
func refresh(world: SimWorld, now_s: float) -> void:
	if _panel.bound_world() != world:
		_panel.bind(world)
	if not _model.due(now_s):
		return
	show_values(
		world.wave, world.wave_tick, world.cinder.hp, world.cinder.max_hp, world.economy.scrap, world.economy.data_run
	)


## Pure setter (also used by tests). Labels are rewritten only when their text changes.
func show_values(wave: int, wave_tick: int, hp: float, max_hp: float, scrap: BigNum, data: BigNum) -> void:
	_timer_bar.value = float(wave_tick)
	_integrity_bar.max_value = maxf(max_hp, 1.0)
	_integrity_bar.value = clampf(hp, 0.0, maxf(max_hp, 1.0))
	_style_integrity(hp / maxf(max_hp, 1.0))
	_model.set_values(wave, hp, max_hp, scrap, data)
	_set_text(_wave_label, _model.wave_text)
	_set_text(_hp_label, _model.hp_text)
	_set_text(_scrap_label, _model.scrap_text)
	_set_text(_data_label, _model.data_text)


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


func _on_buy_requested(upgrade_index: int, count: int) -> void:
	buy_requested.emit(upgrade_index, count)


static func _set_text(label: Label, text: String) -> void:
	if label.text != text:
		label.text = text


func _update_speed_text() -> void:
	_speed_button.text = "%dx" % SPEEDS[_speed_index]


func _update_pause_text() -> void:
	_pause_button.text = Strings.get_text("hud.resume" if _paused else "hud.pause")


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
