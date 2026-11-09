class_name HomeScreen
extends MenuScreen
## STUB (M3-14), replaced by M3-15. Signals are final: deploy_pressed, foundry_pressed, settings_pressed.
## Registered in `ScreenRegistry`; implement it by editing this folder only.

signal deploy_pressed
signal foundry_pressed
signal settings_pressed

var nav_foundry: Button


func title_key() -> String:
	return "home.header"


func _build() -> void:
	content.add_child(make_button("home.deploy", deploy_pressed.emit))
	nav_foundry = make_button("nav.foundry", foundry_pressed.emit)
	content.add_child(nav_foundry)
	content.add_child(make_button("nav.settings", settings_pressed.emit))
	enter()


## The Foundry entry is hidden until the first death (MetaUnlocks).
func enter() -> void:
	if nav_foundry != null:
		nav_foundry.visible = MetaUnlocks.foundry_screen_unlocked(Game.profile())
