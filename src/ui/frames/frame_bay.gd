class_name FrameBay
extends MenuScreen
## STUB (M3-14), replaced by M3-29. Signals are final: confirmed, back_pressed.

signal confirmed
signal back_pressed


func title_key() -> String:
	return "frame.bay_title"


func _build() -> void:
	content.add_child(make_button("title.continue", confirmed.emit))
	content.add_child(make_button("foundry.back", back_pressed.emit))
