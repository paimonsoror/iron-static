extends Node
## Autoload `Game`: app-level singleton (version, boot).

const VERSION: String = "0.0.1"


func _ready() -> void:
	Log.info("game boot, version " + VERSION)
