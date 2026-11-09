class_name ResultsOverlay
extends Control
## End-of-deployment screen (M1-23, restyled V1-18, M3-17, image-first M4; GDD 07 section 2.10): a chamfered plate
## with brackets. `ResultsBody` shows the wave reached as the biggest text with the mode chip, best and NEW BEST
## badge, the killer's battle sprite, stat tiles (time, kills, data banked with the new total, scrap; icons and
## numbers through `NumberFormat`), a kill strip of enemy sprites with counts and compact unlock badges. This node
## adds the save warning and REDEPLOY (primary, pulsing), FOUNDRY (after the first death; pulses when a row is
## affordable) and HOME buttons.
## Entry animation timing lives in `ResultsAnim` (pure, tested); numbers count up and end on the exact model text.
## Reduce motion (`reduce_motion` or `Game.visual.reduce_motion`, read only): everything is final at once.
## Texts come from `ResultsModel` and data/strings_en.csv. Hidden by default; blocks touches to the HUD while shown.
## Signals only (the router routes them); the overlay reads the profile through `BankedInfo` and never banks.
## The buttons are tappable from the first frame (ResultsAnim.BUTTONS_ENABLED_S = 0).

signal redeploy_pressed
signal foundry_pressed
signal home_pressed

const BRACKET_PAD: float = 6.0
## Animated sections of the body (header, killer, tiles, kill strip, badges).
const ROW_COUNT: int = ResultsBody.SECTION_COUNT

## Set true to force reduce motion (it is also read from `Game.visual.reduce_motion`).
var reduce_motion: bool = false
## FTUE hook (M4-26): the FOUNDRY button pulses like the "can afford" pulse while the hint is up.
var ftue_pulse: bool = false

var _model: ResultsModel = null
var _world: SimWorld = null
var _banked: BankedInfo = null
var _wave_final: int = 0
var _kills_final: int = 0
var _data_final: float = 0.0
var _scrap_final: float = 0.0
var _t: float = 0.0
var _settled: bool = false
## True while `show_results` itself shows the overlay (that visibility change must not refresh from the profile).
var _fresh: bool = false
var _frame: Control = null

@onready var _holder: Control = %Holder
@onready var _card: PanelContainer = %Card
@onready var _body: ResultsBody = %Body
@onready var _save_warn: Label = %SaveWarnLabel
@onready var _button: Button = %RedeployButton
@onready var _foundry_button: Button = %FoundryButton
@onready var _home_button: Button = %HomeButton


func _ready() -> void:
	theme = ThemeBuilder.shared()
	_button.text = Strings.get_text("results.redeploy")
	_home_button.text = Strings.get_text("results.home")
	_foundry_button.text = Strings.get_text("results.foundry")
	_save_warn.add_theme_color_override("font_color", Palette.WARNING)
	_button.add_theme_color_override("font_color", Palette.AMBER_GLOW)
	_button.add_theme_font_override("font", _body.wave_label().get_theme_font("font", ThemeBuilder.VAR_LABEL_HEADING))
	_build_frame()
	_button.pressed.connect(_on_redeploy)
	_foundry_button.pressed.connect(_on_foundry)
	_home_button.pressed.connect(_on_home)
	visibility_changed.connect(_on_visibility_changed)
	set_process(false)


## Fills the fields from a finished world, starts the entry animation and shows the overlay. `banked` defaults to
## what `Game` banked for this run (`BankedInfo.from_game`); tests may pass their own.
func show_results(world: SimWorld, banked: BankedInfo = null) -> void:
	_world = world
	_banked = banked if banked != null else BankedInfo.from_game(world)
	_build_model()
	_wave_final = world.run.death_wave
	_kills_final = world.run.kills
	_data_final = world.economy.data_run.to_float()
	_scrap_final = world.run.scrap_earned
	_t = 0.0
	_settled = false
	_fresh = true
	show()
	_fresh = false
	_apply(0.0)
	set_process(true)


func hide_results() -> void:
	hide()
	set_process(false)


## Advances the entry animation by `delta` seconds (`_process` calls this; tests may too).
func advance(delta: float) -> void:
	_t += delta
	_apply(_t)


## Global rect of the FOUNDRY button (the FTUE pointer target); Rect2() while it is hidden.
func foundry_rect() -> Rect2:
	return _foundry_button.get_global_rect() if _foundry_button.is_visible_in_tree() else Rect2()


func is_settled() -> bool:
	return _settled


func model() -> ResultsModel:
	return _model


func body() -> ResultsBody:
	return _body


func _process(delta: float) -> void:
	advance(delta)


func _reduced() -> bool:
	return reduce_motion or Game.visual.reduce_motion


func _build_model() -> void:
	var ids := PackedStringArray()
	for def: EnemyDef in _world.config.enemies:
		ids.append(def.id)
	var idx: int = _world.run.death_cause
	var killer: String = ids[idx] if idx >= 0 and idx < ids.size() else ""
	_model = ResultsModel.from_run(
		_world.run, _world.economy, _world.tick, RunController.cause_text(_world), _banked, ids, killer
	)
	_body.show_model(_model)
	_save_warn.visible = not _model.save_warning_text.is_empty()
	_save_warn.text = _model.save_warning_text
	_foundry_button.visible = _model.foundry_visible
	_foundry_button.text = _model.foundry_text if _model.foundry_visible else Strings.get_text("results.foundry")
	_foundry_button.add_theme_color_override(
		"font_color", Palette.AMBER_GLOW if _model.foundry_pulse else Palette.AMBER
	)


## Coming back from the Foundry the router only calls `show()`: resume the animation and refresh the Foundry badge
## and total (the player may have spent data).
func _on_visibility_changed() -> void:
	if not visible or _model == null or _world == null or _fresh:
		return
	if _banked != null and _banked.has_bank and Game.saves != null:
		var profile: PlayerProfile = Game.saves.profile
		_banked.data_total = profile.data
		_banked.affordable_count = BankedInfo.affordable_foundry(profile, _world.config.upgrades)
		_banked.foundry_unlocked = MetaUnlocks.foundry_screen_unlocked(profile)
		_build_model()
		_apply(_t)
	set_process(not _settled)


func _apply(t: float) -> void:
	var red: bool = _reduced()
	_holder.modulate.a = ResultsAnim.header_alpha(t, red)
	_holder.position.y = ResultsAnim.slide_offset(t, red)
	var sections: Array[Control] = _body.sections()
	for k: int in sections.size():
		sections[k].modulate.a = ResultsAnim.line_alpha(k, t, red)
	if t >= ResultsAnim.total_s(ROW_COUNT, red):
		_snap_final()
	else:
		_body.set_wave(Strings.fill1("results.wave_big", "n", str(roundi(_roll(float(_wave_final), 0, t, red)))))
		_body.set_kills(_num(_roll(float(_kills_final), 2, t, red)))
		_body.set_data(_model.data_gain(_num(_roll(_data_final, 2, t, red))))
		_body.set_scrap(_num(_roll(_scrap_final, 2, t, red)))
	var pulse: float = ResultsAnim.pulse(t, red)
	_button.self_modulate = Color(1.0 + pulse, 1.0 + pulse * 0.7, 1.0 + pulse * 0.3, 1.0)
	var fp: float = pulse if (_model.foundry_pulse or ftue_pulse) else 0.0
	_foundry_button.self_modulate = Color(1.0 + fp, 1.0 + fp * 0.7, 1.0 + fp * 0.3, 1.0)


func _roll(final_value: float, row: int, t: float, red: bool) -> float:
	return ResultsAnim.tally(final_value, t, ResultsAnim.reveal_time(row), red)


func _num(v: float) -> String:
	return NumberFormat.format(BigNum.from_float(floorf(v)))


## Writes the exact model texts (no rounding drift) once the tallies are done.
func _snap_final() -> void:
	_body.set_wave(_model.wave_big_text)
	_body.set_kills(_model.kills_value_text)
	_body.set_data(_model.data_gain(NumberFormat.format(_world.economy.data_run)))
	_body.set_scrap(_model.scrap_value_text)
	_settled = true


func _on_redeploy() -> void:
	AudioHooks.tap()
	redeploy_pressed.emit()


func _on_foundry() -> void:
	AudioHooks.tap()
	foundry_pressed.emit()


func _on_home() -> void:
	AudioHooks.tap()
	home_pressed.emit()


## Amber corner brackets follow the card (a plain Control: a container would re-lay them out).
func _build_frame() -> void:
	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_frame)
	UiKit.add_brackets(_frame, BRACKET_PAD)
	_card.item_rect_changed.connect(_sync_frame)
	_sync_frame.call_deferred()


func _sync_frame() -> void:
	_frame.position = _card.position
	_frame.size = _card.size
