class_name AudioSlot
extends RefCounted
## One row of `assets/audio/slots.csv`: an audio file plus how it is played. Swapping a commissioned sound =
## replace the file (same name or edit `file`) and keep the row.

var id: String = ""
## Path relative to `res://assets/audio/` (empty = reserved, no file yet).
var file: String = ""
var bus: String = "SFX"
var volume_db: float = 0.0
## Random pitch spread as a fraction (0.03 = +-3%); presentation RNG only.
var pitch_var: float = 0.0
## Max simultaneous voices of this id (music rows: 1).
var voice_cap: int = 1
## Minimum time between two starts of this id, in ms.
var cooldown_ms: int = 0
var valid: bool = false


func is_music() -> bool:
	return file.begins_with("music/")


func is_ambience() -> bool:
	return file.begins_with("amb/")


func is_reserved() -> bool:
	return file.is_empty()
