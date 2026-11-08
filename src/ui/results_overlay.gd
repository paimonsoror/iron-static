class_name ResultsOverlay
extends Control
## End-of-deployment screen (M1-23; GDD 07 section 2.10 results fields): wave reached, game time, kills,
## cause of death, data and scrap earned (`NumberFormat`), best-wave delta `--` (M3) and a REDEPLOY button.
## Texts come from `ResultsModel` and data/strings_en.csv. Hidden by default; blocks touches to the HUD while
## shown. Signals only.

signal redeploy_pressed

@onready var _title: Label = %TitleLabel
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
	_cause.add_theme_color_override("font_color", Palette.ENEMY_OUTLINE)
	_data.add_theme_color_override("font_color", Palette.DATA)
	_scrap.add_theme_color_override("font_color", Palette.SCRAP)
	_style_button()
	_button.pressed.connect(_on_pressed)


## Fills the fields from a finished world and shows the overlay.
func show_results(world: SimWorld) -> void:
	var m: ResultsModel = ResultsModel.from_run(world.run, world.economy, world.tick, RunController.cause_text(world))
	_wave.text = m.wave_text
	_time.text = m.time_text
	_kills.text = m.kills_text
	_cause.text = m.cause_text
	_data.text = m.data_text
	_scrap.text = m.scrap_text
	_best.text = m.best_text
	show()


func hide_results() -> void:
	hide()


func _on_pressed() -> void:
	redeploy_pressed.emit()


func _style_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Palette.PANEL
	normal.border_color = Palette.AMBER
	normal.set_border_width_all(4)
	normal.set_corner_radius_all(10)
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Palette.AMBER_DIM
	_button.add_theme_stylebox_override("normal", normal)
	_button.add_theme_stylebox_override("hover", normal)
	_button.add_theme_stylebox_override("pressed", pressed)
	_button.add_theme_color_override("font_color", Palette.AMBER)
	_button.add_theme_color_override("font_hover_color", Palette.AMBER)
	_button.add_theme_color_override("font_pressed_color", Palette.TEXT)
	_button.add_theme_color_override("font_focus_color", Palette.AMBER)
