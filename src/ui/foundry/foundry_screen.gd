class_name FoundryScreen
extends MenuScreen
## STUB (M3-14), replaced by M3-16. Signals are final: deploy_pressed, back_pressed.

signal deploy_pressed
signal back_pressed


func title_key() -> String:
	return "foundry.title"


func _build() -> void:
	content.add_child(make_button("foundry.deploy", deploy_pressed.emit))
	content.add_child(make_button("foundry.back", back_pressed.emit))
