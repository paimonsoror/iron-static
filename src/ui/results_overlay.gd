class_name ResultsOverlay
extends Control
## End-of-deployment screen (M1-23, restyled V1-18; GDD 07 section 2.10 results fields): a chamfered plate with
## brackets showing wave reached, game time, kills, cause of death (killer chip + the enemy's accent color), data and
## scrap earned (currency icons, `NumberFormat`), best-wave delta `--` (M3) and a pulsing REDEPLOY button.
## Entry animation timing lives in `ResultsAnim` (pure, tested); numbers count up and end on the exact model text.
## Reduce motion (`reduce_motion` or `Game.visual.reduce_motion`, read only): everything is final at once.
## Texts come from `ResultsModel` and data/strings_en.csv. Hidden by default; blocks touches to the HUD while shown.
## Signals only. The button is tappable from the first frame (ResultsAnim.BUTTONS_ENABLED_S = 0).

signal redeploy_pressed

const ICON_PX: float = 56.0
const BRACKET_PAD: float = 6.0
const ROW_COUNT: int = 7
const ROW_NAMES: Array[String] = ["WaveRow", "TimeRow", "KillsRow", "CauseRow", "DataRow", "ScrapRow", "BestRow"]

## Set true to force reduce motion (it is also read from `Game.visual.reduce_motion`).
var reduce_motion: bool = false

var _model: ResultsModel = null
var _wave_final: int = 0
var _kills_final: int = 0
var _data_final: float = 0.0
var _scrap_final: float = 0.0
var _t: float = 0.0
var _settled: bool = false
var _frame: Control = null
var _rows: Array[Control] = []
var _chip: TextureRect = null

@onready var _holder: Control = %Holder
@onready var _card: PanelContainer = %Card
@onready var _title: Label = %TitleLabel
@onready var _stripe: Panel = %Stripe
@onready var _wave: Label = %WaveLabel
@onready var _time: Label = %TimeLabel
@onready var _kills: Label = %KillsLabel
@onready var _cause: Label = %CauseLabel
@onready var _data: Label = %DataLabel
@onready var _scrap: Label = %ScrapLabel
@onready var _best: Label = %BestLabel
@onready var _button: Button = %RedeployButton


func _ready() -> void:
	theme = ThemeBuilder.shared()
	_title.text = Strings.get_text("results.title")
	_button.text = Strings.get_text("results.redeploy")
	_title.add_theme_color_override("font_color", Palette.AMBER)
	for label: Label in [_wave, _time, _kills]:
		label.add_theme_color_override("font_color", Palette.TEXT)
	_cause.add_theme_color_override("font_color", Palette.ACCENT_SKITTER)
	_data.add_theme_color_override("font_color", Palette.DATA)
	_scrap.add_theme_color_override("font_color", Palette.SCRAP)
	_best.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_button.add_theme_color_override("font_color", Palette.AMBER_GLOW)
	_button.add_theme_font_override("font", _title.get_theme_font("font", ThemeBuilder.VAR_LABEL_HEADING))
	_stripe.add_theme_stylebox_override("panel", UiKit.hazard_stripe())
	_build_icons()
	_build_frame()
	for n: String in ROW_NAMES:
		_rows.append(get_node("%" + n) as Control)
	_button.pressed.connect(_on_pressed)
	set_process(false)


## Fills the fields from a finished world, starts the entry animation and shows the overlay.
func show_results(world: SimWorld) -> void:
	_model = ResultsModel.from_run(world.run, world.economy, world.tick, RunController.cause_text(world))
	_wave_final = world.run.death_wave
	_kills_final = world.run.kills
	_data_final = world.economy.data_run.to_float()
	_scrap_final = world.run.scrap_earned
	_time.text = _model.time_text
	_best.text = _model.best_text
	_set_cause(world)
	_t = 0.0
	_settled = false
	show()
	_apply(0.0)
	set_process(true)


func hide_results() -> void:
	hide()
	set_process(false)


## Advances the entry animation by `delta` seconds (`_process` calls this; tests may too).
func advance(delta: float) -> void:
	_t += delta
	_apply(_t)


func is_settled() -> bool:
	return _settled


func _process(delta: float) -> void:
	advance(delta)


func _reduced() -> bool:
	return reduce_motion or Game.visual.reduce_motion


func _apply(t: float) -> void:
	var red: bool = _reduced()
	_holder.modulate.a = ResultsAnim.header_alpha(t, red)
	_holder.position.y = ResultsAnim.slide_offset(t, red)
	_title.position.x = ResultsAnim.header_jitter(t, red)
	for k: int in _rows.size():
		_rows[k].modulate.a = ResultsAnim.line_alpha(k, t, red)
	if t >= ResultsAnim.total_s(ROW_COUNT, red):
		_snap_final()
	else:
		_wave.text = Strings.fill1("results.wave", "n", str(roundi(_roll(float(_wave_final), 0, t, red))))
		_kills.text = Strings.fill1("results.kills", "v", _num(_roll(float(_kills_final), 2, t, red)))
		_data.text = Strings.fill1("results.data", "v", _num(_roll(_data_final, 4, t, red)))
		_scrap.text = Strings.fill1("results.scrap", "v", _num(_roll(_scrap_final, 5, t, red)))
	var pulse: float = ResultsAnim.pulse(t, red)
	_button.self_modulate = Color(1.0 + pulse, 1.0 + pulse * 0.7, 1.0 + pulse * 0.3, 1.0)


func _roll(final_value: float, row: int, t: float, red: bool) -> float:
	return ResultsAnim.tally(final_value, t, ResultsAnim.reveal_time(row), red)


func _num(v: float) -> String:
	return NumberFormat.format(BigNum.from_float(floorf(v)))


## Writes the exact model texts (no rounding drift) once the tallies are done.
func _snap_final() -> void:
	_wave.text = _model.wave_text
	_kills.text = _model.kills_text
	_data.text = _model.data_text
	_scrap.text = _model.scrap_text
	_settled = true


func _set_cause(world: SimWorld) -> void:
	_cause.text = _model.cause_text
	var idx: int = world.run.death_cause
	var id: String = ""
	if idx >= 0 and idx < world.config.enemies.size():
		id = world.config.enemies[idx].id
	_cause.add_theme_color_override("font_color", ResultsAnim.accent_for(id))
	if ArtSlots.has(id):
		_chip.texture = ArtSlots.atlas(id, 0)
	else:
		_chip.texture = null


func _on_pressed() -> void:
	redeploy_pressed.emit()


func _build_icons() -> void:
	for row_name: String in ["WaveRow", "TimeRow", "KillsRow", "BestRow"]:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_add_lead(row_name, spacer)
	_chip = UiKit.icon_rect("icon_cur_data", ICON_PX)
	_chip.texture = null
	_add_lead("CauseRow", _chip)
	_add_lead("DataRow", UiKit.icon_rect("icon_cur_data", ICON_PX))
	_add_lead("ScrapRow", UiKit.icon_rect("icon_cur_scrap", ICON_PX))


func _add_lead(row_name: String, node: Control) -> void:
	var row: Control = get_node("%" + row_name)
	row.add_child(node)
	row.move_child(node, 0)


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
