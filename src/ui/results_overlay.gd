class_name ResultsOverlay
extends Control
## End-of-deployment screen (M1-23; GDD 07 section 2.10 results fields): wave reached, game time, kills,
## cause of death, data and scrap earned (M1 floats shown as integers) and a REDEPLOY button.
## Hidden by default; blocks touches to the HUD while shown. Signals only.
## (impl) UI strings are constants here: data/strings_en.csv does not exist yet.

signal redeploy_pressed

@onready var _title: Label = %TitleLabel
@onready var _wave: Label = %WaveLabel
@onready var _time: Label = %TimeLabel
@onready var _kills: Label = %KillsLabel
@onready var _cause: Label = %CauseLabel
@onready var _data: Label = %DataLabel
@onready var _scrap: Label = %ScrapLabel
@onready var _button: Button = %RedeployButton


func _ready() -> void:
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
	_wave.text = "WAVE REACHED  %d" % world.run.death_wave
	_time.text = "TIME  %s" % RunController.time_text(world.tick)
	_kills.text = "KILLS  %d" % world.run.kills
	_cause.text = "CAUSE  %s" % RunController.cause_text(world)
	_data.text = "DATA  %d" % floori(world.run.data_earned)
	_scrap.text = "SCRAP  %d" % floori(world.run.scrap_earned)
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
