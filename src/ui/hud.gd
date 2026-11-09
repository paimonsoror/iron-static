class_name Hud
extends Control
## Battle HUD (GDD 07 section 2.1: hud_wave, hud_timer_bar, hud_speed, hud_pause, hud_integrity_ring as a bar,
## hud_scrap amber, hud_data_run blue) plus the bottom `UpgradePanel` (M2-10), styled per art bible 7.2 (V1-16) and
## compacted in V1-25: line 1 wave + time left + speed + 80 px speed/pause icons (126 px touch rects), line 2 24 px
## timer bar, line 3 integrity bar, line 4 currency chips (about 250 px tall). Base resolution 1080 wide.
## `field_rect_changed(rect)` (V1-28) and `field_insets_changed(top_px, bottom_px)` report the open field for
## `BattleView.set_field_rect` (deferred, coalesced). Aspect below 0.72 = PORTRAIT, from 0.78 = WIDE (`LayoutMode`).
## Signals only; the owner feeds values with refresh(world, now_s) at any rate. Counter text comes from `HudModel`
## (10 Hz throttle, `NumberFormat`); a label is rewritten only when its text changed. Scrap and data roll to new
## values over 0.25 s (`NumberRoll`, stepped by the same 10 Hz refresh; instant under reduce motion). The panel is
## bound to the world on the first refresh of each new world; its `buy_requested` is re-emitted here for M2-12.

signal speed_changed(multiplier: int)
signal pause_toggled(paused: bool)
signal buy_requested(upgrade_index: int, count: int)
signal field_insets_changed(top_px: float, bottom_px: float)
signal field_rect_changed(rect: Rect2)

const SPEEDS: Array[int] = [1, 2]
## Counter plate icon size and offset (inside the 92 px plate).
const COUNTER_ICON_PX: float = 48.0
const COUNTER_ICON_POS: Vector2 = Vector2(20.0, 8.0)
## Upgrade panel height cap as a share of the viewport height.
const PANEL_MAX_SHARE: float = 0.36
## Touch rect of the 80 px icon buttons: 80 + 2 x 23 = 126 px (48 dp).
## Timer bar frame inset: 24 px bar leaves 16 px tall segments (V1-27).
const TIMER_INSET: float = 4.0
## Right edge of the timer label: wide enough for "999 LEFT" in PURGE (the speed label starts at 700).
const TIMED_LABEL_RIGHT: float = 620.0
const PURGE_LABEL_RIGHT: float = 690.0
const TOUCH_PAD_PX: float = 23.0

## Set true to force reduce motion (it is also read from `Game.visual.reduce_motion`).
var reduce_motion: bool = false

var _speed_index: int = 0
var _paused: bool = false
var _model: HudModel = HudModel.new()
var _last_wave: int = -1
## PURGE (M4-09): enemies left in the wave quota (-1 = TIMED, the clock shows) and the backstop length in ticks.
var _quota_left: int = -1
var _bar_ticks: int = Ticks.WAVE_TICKS
var _boss_warn: HudBossWarning = null
var _scrap_roll: NumberRoll = NumberRoll.new()
var _data_roll: NumberRoll = NumberRoll.new()
var _insets_dirty: bool = false
var _last_insets: Vector2 = Vector2(-1.0, -1.0)
var _last_rect := Rect2()
var _mode: LayoutMode.Mode = LayoutMode.Mode.PORTRAIT
var _safe := Vector4.ZERO

@onready var _wave_label: Label = %WaveLabel
@onready var _timer_bar: SegmentedBar = %TimerBar
@onready var _timer_label: Label = %TimerLabel
@onready var _speed_label: Label = %SpeedLabel
@onready var _speed_button: TouchButton = %SpeedButton
@onready var _pause_button: TouchButton = %PauseButton
@onready var _integrity_bar: SegmentedBar = %IntegrityBar
@onready var _hp_label: Label = %HpLabel
@onready var _scrap_label: Label = %ScrapLabel
@onready var _data_label: Label = %DataLabel
@onready var _banner: WaveBanner = %WaveBanner
@onready var _panel: UpgradePanel = %UpgradePanel
@onready var _top_bar: Control = %TopBar


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
	_timer_bar.inset = TIMER_INSET
	_integrity_bar.animate = not _reduced()
	UiKit.style_icon_button(_speed_button, "icon_ic_speed")
	UiKit.style_icon_button(_pause_button, "icon_ic_pause")
	_speed_button.pressed.connect(_on_speed_pressed)
	_pause_button.pressed.connect(_on_pause_pressed)
	_speed_button.touch_pad = TOUCH_PAD_PX
	_pause_button.touch_pad = TOUCH_PAD_PX
	_boss_warn = HudBossWarning.new()
	_boss_warn.name = "BossWarning"
	add_child(_boss_warn)
	_boss_warn.boss_arrived.connect(_on_boss_arrived)
	_panel.buy_requested.connect(_on_buy_requested)
	_panel.resized.connect(_mark_insets_dirty)
	resized.connect(_on_resized)
	_update_speed_text()
	_update_pause_text()
	_on_resized()


## The upgrade panel (for M2-12 wiring and tests).
func upgrade_panel() -> UpgradePanel:
	return _panel


## Insets the top bar and the panel by the OS safe area (`SafeArea.margins`: left, top, right, bottom in viewport
## px; cutouts, rounded corners) in either layout. Zero margins restore the scene layout.
func apply_safe_margins(m: Vector4) -> void:
	_safe = m
	_apply_layout()


## The active layout (V1-28): PORTRAIT below aspect 0.72, WIDE from 0.78, with hysteresis (`LayoutMode`).
func layout_mode() -> LayoutMode.Mode:
	return _mode


## Open field insets in this control's pixels: `x` = HUD bottom edge, `y` = screen height minus panel top (WIDE: only
## the bottom safe margin, the panel is a side column).
func field_insets() -> Vector2:
	var top: float = 0.0
	for plate: Control in [%ScrapPlate, %DataPlate, %TopPlate, %IntegrityBar]:
		top = maxf(top, plate.global_position.y + plate.size.y - global_position.y)
	if _mode == LayoutMode.Mode.WIDE:
		return Vector2(top, _safe.w)
	var bottom: float = size.y - (_panel.global_position.y - global_position.y)
	return Vector2(top, bottom)


## The open field as a rect (V1-28): portrait spans the width between HUD and panel; wide is left of the side panel.
func field_rect() -> Rect2:
	var v: Vector2 = field_insets()
	if _mode == LayoutMode.Mode.WIDE:
		return LayoutRects.field(size, _safe, v.x)
	return ViewMath.field_rect(size, v.x, v.y)


func _apply_layout() -> void:
	HudLayout.apply(_mode, size, _safe, _top_bar, _panel, _banner)
	_mark_insets_dirty()


func _on_resized() -> void:
	_mode = LayoutMode.pick(size, _mode)
	_panel.max_height_px = size.y * PANEL_MAX_SHARE
	_apply_layout()


func _mark_insets_dirty() -> void:
	if _insets_dirty or not is_inside_tree():
		return
	_insets_dirty = true
	_flush_insets.call_deferred()


func _flush_insets() -> void:
	_insets_dirty = false
	var v: Vector2 = field_insets()
	var rect: Rect2 = field_rect()
	if v != _last_insets:
		_last_insets = v
		field_insets_changed.emit(v.x, v.y)
	if rect != _last_rect:
		_last_rect = rect
		field_rect_changed.emit(rect)


## The wave banner (tests).
func wave_banner() -> WaveBanner:
	return _banner


## Pulls values from the world; cheap to call every frame (throttled to HudModel.REFRESH_S of `now_s`).
func refresh(world: SimWorld, now_s: float) -> void:
	if _panel.bound_world() != world:
		_panel.bind(world)
	_boss_warn.reduce_motion = _reduced()
	_boss_warn.update(world, field_rect(), _chip_anchor())
	if not _model.due(now_s):
		return
	var boss: bool = world.is_boss_wave(world.wave)
	var purge: bool = world.config.wave_mode == SimConfig.MODE_PURGE
	_quota_left = PurgeClock.remaining_quota(world) if purge else -1  # read-only: the HUD never mutates the sim
	_bar_ticks = PurgeClock.backstop_ticks(world) if purge else Ticks.WAVE_TICKS
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
	_timer_bar.max_value = float(_bar_ticks)  # PURGE: the thin bar is the 60 s backstop, not the wave clock
	_timer_label.offset_right = PURGE_LABEL_RIGHT if _quota_left >= 0 else TIMED_LABEL_RIGHT
	_timer_bar.value = float(wave_tick)
	_integrity_bar.max_value = maxf(max_hp, 1.0)
	_integrity_bar.value = clampf(hp, 0.0, maxf(max_hp, 1.0))
	var roll: bool = now_s >= 0.0 and not _reduced()
	var shown_scrap: BigNum = _rolled(_scrap_roll, scrap, now_s, roll)
	var shown_data: BigNum = _rolled(_data_roll, data, now_s, roll)
	_model.set_values(wave, hp, max_hp, shown_scrap, shown_data, wave_tick, _quota_left)
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
	AudioHooks.tap()
	_speed_index = (_speed_index + 1) % SPEEDS.size()
	_update_speed_text()
	speed_changed.emit(SPEEDS[_speed_index])


func _on_pause_pressed() -> void:
	_paused = not _paused
	_update_pause_text()
	# (impl) The HUD pause stops audio like the app pause: voices and music freeze. The tap sounds before the
	# freeze and after the thaw, because a paused director plays nothing.
	if _paused:
		AudioHooks.tap()
		AudioHooks.pause_audio()
	else:
		AudioHooks.resume_audio()
		AudioHooks.tap()
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


## The boss warning layer (M4-17, tests).
func boss_warning() -> HudBossWarning:
	return _boss_warn


## Right of the wave counter text, vertically centred on it (the chip's spot).
func _chip_anchor() -> Vector2:
	var r: Rect2 = _wave_label.get_global_rect()
	var text_w: float = _wave_label.get_minimum_size().x
	return (
		r.position - global_position + Vector2(minf(text_w, r.size.x) + HudBossWarning.CHIP_SIZE * 1.6, r.size.y * 0.5)
	)


## The boss is on the field: the banner names it (BOSS_SPAWNED, M4-17).
func _on_boss_arrived() -> void:
	_banner.play(Strings.get_text("hud.warning"), true, Strings.get_text("hud.boss_incoming"), _reduced())
