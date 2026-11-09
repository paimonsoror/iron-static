class_name TitleScreen
extends MenuScreen
## STUB (M3-14), replaced by M3-28. Signals are final: continue_pressed, new_game_pressed, settings_pressed,
## quit_confirmed. Back on the title shows the QUIT? confirm: `on_back` consumes it; the router quits on YES.

signal continue_pressed
signal new_game_pressed
signal settings_pressed
signal quit_confirmed

var _menu: Array[Control] = []
var _quit_box: VBoxContainer


func _build() -> void:
	heading.text = Strings.fill1("title.version", "v", Game.VERSION)
	heading.visible = true
	_menu = [
		make_button("title.continue", continue_pressed.emit),
		make_button("title.new_game", new_game_pressed.emit),
		make_button("title.settings", settings_pressed.emit),
	]
	for c: Control in _menu:
		content.add_child(c)
	_quit_box = VBoxContainer.new()
	_quit_box.add_theme_constant_override("separation", SEPARATION)
	_quit_box.add_child(label("title.quit_title", &"LabelHeading", Palette.AMBER, 80))
	_quit_box.add_child(make_button("title.quit_yes", quit_confirmed.emit))
	_quit_box.add_child(make_button("title.quit_no", _close_quit))
	_quit_box.visible = false
	content.add_child(_quit_box)


func on_back() -> bool:
	if _quit_box.visible:
		_close_quit()
	else:
		_quit_box.visible = true
		for c: Control in _menu:
			c.visible = false
	return true


func _close_quit() -> void:
	_quit_box.visible = false
	for c: Control in _menu:
		c.visible = true
