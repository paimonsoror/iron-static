class_name SettingsScreen
extends MenuScreen
## STUB (M3-14), replaced by M3-18. Signal is final: back_pressed.

signal back_pressed


func title_key() -> String:
	return "settings.title"


func _build() -> void:
	content.add_child(make_button("settings.back", back_pressed.emit))
