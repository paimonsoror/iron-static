class_name AdsStub
extends AdsService
## Desktop/headless ads: no SDK. `initialize()` succeeds immediately; loading and showing fail with -1.

const CODE_UNAVAILABLE: int = -1


func backend_name() -> String:
	return "stub"


func initialize() -> void:
	initialized.emit()


func load_rewarded(_placement: String) -> void:
	failed.emit(CODE_UNAVAILABLE)


func show_rewarded(_placement: String) -> void:
	failed.emit(CODE_UNAVAILABLE)
