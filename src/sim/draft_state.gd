class_name DraftState
extends RefCounted
## The patch draft in progress (GDD 02 section 10; M4-15). `open` while the player (or a bot policy) has to pick:
## `SimWorld.step()` does nothing until `command_pick`. `offers` holds patch indices (rows of `SimConfig.patches`),
## one per slot; `wave` is the wave whose end opened the draft. Closed state (all defaults) adds nothing to the hash.

var open: bool = false
var wave: int = 0
var offers: PackedInt32Array = PackedInt32Array()


func close() -> void:
	open = false
	wave = 0
	offers = PackedInt32Array()
