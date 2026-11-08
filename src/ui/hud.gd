class_name Hud
extends Control
## Battle HUD (GDD 07 section 2.1: hud_wave, hud_timer_bar, hud_speed, hud_pause, hud_integrity_ring as a bar,
## hud_scrap amber, hud_data_run blue) plus the bottom-44% `UpgradePanel` (M2-10), styled per art bible 7.2 (V1-16):
## top plate with brackets, segmented timer and integrity bars (numbers in a reserved pocket), counter plates with
## currency icons, icon buttons and a wave banner. Base resolution 1080 wide; buttons are 148 px squares.
## Signals only; the owner feeds values with refresh(world, now_s) at any rate. Counter text comes from `HudModel`
## (10 Hz throttle, `NumberFormat`); a label is rewritten only when its text changed. Scrap and data roll to new
## values over 0.25 s (`NumberRoll`, stepped by the same 10 Hz refresh; instant under reduce motion). The panel is
## bound to the world on the first refresh of each new world; its `buy_requested` is re-emitted here for M2-12.

signal speed_changed(multiplier: int)
signal pause_toggled(paused: bool)
signal buy_requested(upgrade_index: int, count: int)

const SPEEDS: Array[int] = [1, 2]
## Counter plate icon size and offset (inside the 92 px plate).
const COUNTER_ICON_PX: float = 64.0
const COUNTER_ICON_POS: Vector2 = Vector2(18.0, 14.0)

## Set true to force reduce motion (it is also read from `Game.visual.reduce_motion`).
var reduce_motion: bool = false

var _speed_index: int = 0
var _paused: bool = false
var _model: HudModel = HudModel.new()
var _last_wave: int = -1
var _scrap_roll: NumberRoll = NumberRoll.new()
var _data_roll: NumberRoll = NumberRoll.new()

@onready var _wave_label: Label = %WaveLabel
@onready var _timer_bar: SegmentedBar = %TimerBar
@onready var _timer_label: Label = %TimerLabel
@onready var _speed_label: Label = %SpeedLabel
@onready var _speed_button: Button = %SpeedButton
@onready var _pause_button: Button = %PauseButton
@onready var _integrity_bar: SegmentedBar = %IntegrityBar
@onready var _hp_label: Label = %HpLabel
@onready var _scrap_label: Label = %ScrapLabel
@onready var _data_label: Label = %DataLabel
@onready var _banner: WaveBanner = %WaveBanner
@onready var _panel: UpgradePanel = %UpgradePanel


func _ready() -> void:
	theme = ThemeBuilder.shared()
	_style_label(_wave_label, Palette.AMBER)
	_style_label(_timer_label, Palette.TEXT)
	_style_label(_speed_label, Palette.AMBER_GLOW)
	_style_label(_hp_label, Palette.TEXT)
	_style_label(_scrap_label, Palette.SCRAP)
	_style_label(_data_label, Palette.DATA)
	_style_plate(%TopPlate as Panel)
	UiKit.add_brackets(%TopPlate as Panel)
	_style_counter(%ScrapPlate as Panel, "icon_cur_scrap")
	_style_counter(%DataPlate as Panel, "icon_cur_data")
	_timer_bar.color = Palette.AMBER
	_integrity_bar.animate = not _reduced()
	UiKit.style_icon_button(_speed_button, "icon_ic_speed")
	UiKit.style_icon_button(_pause_button, "icon_ic_pause")
	_speed_button.pressed.connect(_on_speed_pressed)
	_pause_button.pressed.connect(_on_pause_pressed)
	_panel.buy_requested.connect(_on_buy_requested)
	_update_speed_text()
	_update_pause_text()


## The upgrade panel (for M2-12 wiring and tests).
func upgrade_panel() -> UpgradePanel:
	return _panel


## The wave banner (tests).
func wave_banner() -> WaveBanner:
	return _banner


## Pulls values from the world; cheap to call every frame (throttled to HudModel.REFRESH_S of `now_s`).
func refresh(world: SimWorld, now_s: float) -> void:
	if _panel.bound_world() != world:
		_panel.bind(world)
	if not _model.due(now_s):
		return
	var boss: bool = world.is_boss_wave(world.wave)
	_apply(
		world.wave,
		world.wave_tick,
		world.cinder.hp,
		world.cinder.max_hp,
		world.economy.scrap,
		world.economy.data_run,
		boss,
		now_s
	)


## Pure setter (also used by tests): counters jump (no roll) and labels are rewritten only when their text changes.
func show_values(
	wave: int, wave_tick: int, hp: float, max_hp: float, scrap: BigNum, data: BigNum, boss: bool = false
) -> void:
	_apply(wave, wave_tick, hp, max_hp, scrap, data, boss, -1.0)


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


## `now_s` < 0 means "no roll" (jump to the values).
func _apply(
	wave: int, wave_tick: int, hp: float, max_hp: float, scrap: BigNum, data: BigNum, boss: bool, now_s: float
) -> void:
	_timer_bar.value = float(wave_tick)
	_integrity_bar.max_value = maxf(max_hp, 1.0)
	_integrity_bar.value = clampf(hp, 0.0, maxf(max_hp, 1.0))
	var roll: bool = now_s >= 0.0 and not _reduced()
	var shown_scrap: BigNum = _rolled(_scrap_roll, scrap, now_s, roll)
	var shown_data: BigNum = _rolled(_data_roll, data, now_s, roll)
	_model.set_values(wave, hp, max_hp, shown_scrap, shown_data, wave_tick)
	_set_text(_wave_label, _model.wave_text)
	_set_text(_timer_label, _model.timer_text)
	_set_text(_hp_label, _model.hp_text)
	_set_text(_scrap_label, _model.scrap_text)
	_set_text(_data_label, _model.data_text)
	if wave != _last_wave:
		_last_wave = wave
		_play_banner(wave, boss)


## The value to display: the target itself, or an eased float between old and new while a roll runs.
static func _rolled(roll_state: NumberRoll, target: BigNum, now_s: float, roll: bool) -> BigNum:
	# Values beyond float range (never in practice) and rolls disabled jump to the target.
	var t: float = target.to_float()
	var stamp: float = maxf(now_s, 0.0)
	roll_state.set_target(t, stamp, not roll or is_inf(t) or t > 1.0e300)
	if roll_state.is_done(stamp):
		return target
	return BigNum.from_float(floorf(roll_state.value_at(stamp)))


func _play_banner(wave: int, boss: bool) -> void:
	var title: String = Strings.get_text("hud.warning") if boss else Strings.fill1("hud.wave_banner", "n", str(wave))
	var sub: String = Strings.fill1("hud.boss_wave", "n", str(wave)) if boss else ""
	_banner.play(title, boss, sub, _reduced())


func _reduced() -> bool:
	return reduce_motion or Game.visual.reduce_motion


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
	_set_text(_speed_label, "%dx" % SPEEDS[_speed_index])
	_speed_button.tooltip_text = _speed_label.text


func _update_pause_text() -> void:
	UiKit.set_icon(_pause_button, "icon_ic_play" if _paused else "icon_ic_pause")
	_pause_button.tooltip_text = Strings.get_text("hud.resume" if _paused else "hud.pause")


func _style_label(label: Label, col: Color) -> void:
	label.add_theme_color_override("font_color", col)


static func _style_plate(p: Panel) -> void:
	p.add_theme_stylebox_override("panel", UiKit.plate())


static func _style_counter(p: Panel, icon_slot: String) -> void:
	_style_plate(p)
	var icon: TextureRect = UiKit.icon_rect(icon_slot, COUNTER_ICON_PX)
	icon.position = COUNTER_ICON_POS
	icon.size = Vector2(COUNTER_ICON_PX, COUNTER_ICON_PX)
	p.add_child(icon)
