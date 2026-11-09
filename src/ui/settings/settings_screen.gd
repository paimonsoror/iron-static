class_name SettingsScreen
extends MenuScreen
## Settings screen (M3-18): sound and music sliders, mute, reduce motion, shake, scanlines, number format, FPS cap,
## version. Every edit applies live through `SettingsActions` and is persisted (profile settings + save request);
## leaving the screen saves at once. Session overrides (`--mute`, `--shake=`, `--debug-novsync`) carry the
## `settings.note_session` tag until the player edits that control. Back goes to the opener (router).

signal back_pressed

const ROW_GAP: int = 24
const NAME_PX: int = 40
const VALUE_PX: int = 40
const NOTE_PX: int = 32
const SAMPLE_SFX: String = "sfx_ui_tap"

var scroll: ScrollContainer
var sliders: Dictionary[String, SettingsSlider] = {}
var toggles: Dictionary[String, SettingsToggle] = {}
var choices: Dictionary[String, SettingsChoice] = {}
var back_button: Button
var version_label: Label
var example_label: Label
var _value_labels: Dictionary[String, Label] = {}
var _notes: Dictionary[String, Label] = {}


func title_key() -> String:
	return "settings.title"


func _build() -> void:
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.scroll_deadzone = 24
	content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", ROW_GAP)
	scroll.add_child(list)
	for setting: String in SettingsModel.ORDER:
		list.add_child(_make_row(setting))
	version_label = label("", &"LabelDim", Palette.TEXT_DIM, NOTE_PX)
	version_label.text = Strings.fill1("settings.version", "v", Game.VERSION)
	list.add_child(version_label)
	back_button = make_button("settings.back", _on_back)
	content.add_child(back_button)
	enter()


## Refreshes every control from the runtime objects (the router calls this each time the screen is shown).
func enter() -> void:
	if scroll == null:
		return
	var s: PlayerSettings = SettingsActions.current()
	_slider_set(SettingsModel.KEY_SFX, s.sfx)
	_slider_set(SettingsModel.KEY_MUSIC, s.music)
	_toggle_set(SettingsModel.KEY_MUTED, s.muted)
	_toggle_set(SettingsModel.KEY_REDUCE_MOTION, s.reduce_motion)
	var picks: Dictionary[String, String] = {
		SettingsModel.KEY_SHAKE: s.shake,
		SettingsModel.KEY_SCANLINES: s.scanlines,
		SettingsModel.KEY_NUMBER_FORMAT: s.number_format,
		SettingsModel.KEY_FPS_CAP: str(s.fps_cap),
	}
	for key: String in picks:
		choices[key].set_selected_silent(SettingsModel.index_of(key, picks[key]))
	_refresh_state()
	scroll.scroll_vertical = 0


## Saves at once when the screen is hidden.
func leave() -> void:
	if Game.saves != null:
		@warning_ignore("return_value_discarded")
		Game.saves.save_now()


func _on_back() -> void:
	AudioHooks.tap()
	back_pressed.emit()


func _make_row(setting: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var title_text: String = Strings.get_text(SettingsModel.label_key(setting))
	match setting:
		SettingsModel.KEY_SFX, SettingsModel.KEY_MUSIC:
			var sl := SettingsSlider.new()
			sliders[setting] = sl
			sl.value_changed.connect(_on_slider.bind(setting))
			sl.drag_released.connect(_on_slider_released)
			box.add_child(_plate([_header(setting, title_text), sl]))
		SettingsModel.KEY_MUTED, SettingsModel.KEY_REDUCE_MOTION:
			var t := SettingsToggle.new()
			t.text = title_text
			t.toggled.connect(_on_toggle.bind(setting))
			toggles[setting] = t
			box.add_child(t)
		_:
			var c := SettingsChoice.new()
			c.setup(SettingsModel.option_keys(setting), 0)
			c.chosen.connect(_on_choice.bind(setting))
			choices[setting] = c
			box.add_child(_plate([_header(setting, title_text), c]))
			if setting == SettingsModel.KEY_NUMBER_FORMAT:
				example_label = _value_labels[setting]
	var note: Label = label("settings.note_session", &"LabelDim", Palette.WARNING, NOTE_PX)
	note.visible = false
	_notes[setting] = note
	box.add_child(note)
	return box


func _header(setting: String, title_text: String) -> Control:
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := Label.new()
	n.text = title_text
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.add_theme_font_size_override("font_size", NAME_PX)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(n)
	var v: Label = label("", &"LabelNumber", Palette.AMBER, VALUE_PX)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_value_labels[setting] = v
	h.add_child(v)
	return h


func _plate(parts: Array[Control]) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = ThemeBuilder.VAR_PANEL_PLATE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	for c: Control in parts:
		v.add_child(c)
	p.add_child(v)
	return p


func _slider_set(setting: String, value: float) -> void:
	sliders[setting].set_value_silent(value)
	_value_labels[setting].text = SettingsModel.volume_text(value)


func _toggle_set(setting: String, on: bool) -> void:
	toggles[setting].set_value_silent(on)


func _on_slider(value: float, setting: String) -> void:
	SettingsActions.set_volume(setting, value)
	_value_labels[setting].text = SettingsModel.volume_text(value)


func _on_slider_released(changed: bool) -> void:
	if changed:
		@warning_ignore("return_value_discarded")
		AudioHooks.director().play_sfx(SAMPLE_SFX)


func _on_toggle(on: bool, setting: String) -> void:
	if setting == SettingsModel.KEY_MUTED:
		SettingsActions.set_muted(on)
	else:
		SettingsActions.set_reduce_motion(on)
	_refresh_state()


func _on_choice(index: int, setting: String) -> void:
	SettingsActions.set_choice(setting, index)
	_refresh_state()


## Notes, dimmed choices and the number example follow the runtime state.
func _refresh_state() -> void:
	var applier: SettingsApplier = Game.settings_applier
	var reduced: bool = Game.visual.reduce_motion
	for setting: String in SettingsModel.ORDER:
		_notes[setting].visible = applier.is_overridden(setting)
		if choices.has(setting) and SettingsModel.dimmed_by_reduce_motion(setting):
			choices[setting].set_dimmed(reduced)
	example_label.text = SettingsModel.number_example(NumberFormat.style)
