class_name SaveProblemScreen
extends MenuScreen
## Blocking "Save problem" screen (M3-14, Q59). CORRUPT: body plus START NEW PROFILE (damaged files are renamed
## `*.corrupt` by `SaveService.resolve_start_new`, never deleted). TOO_NEW: body only, no button, nothing writes.
## Never dismisses itself; back quits (BackPolicy).

signal resolved

var _body: Label
var _button: Button


func title_key() -> String:
	return "save.problem_title"


func _build() -> void:
	_body = label("save.corrupt_body", &"LabelNumber", Palette.TEXT, 52)
	content.add_child(_body)
	_button = make_button("save.start_new", _on_start_new)
	content.add_child(_button)
	enter()


func enter() -> void:
	if _body == null:
		return
	var too_new: bool = Game.save_problem == SaveService.Problem.TOO_NEW
	_body.text = Strings.get_text("save.too_new_body" if too_new else "save.corrupt_body")
	_button.visible = not too_new


func _on_start_new() -> void:
	if Game.save_problem != SaveService.Problem.CORRUPT:
		return
	if Game.saves.resolve_start_new():
		Game.save_problem = SaveService.Problem.NONE
		resolved.emit()
