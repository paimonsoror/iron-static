class_name DraftState
extends RefCounted
## The patch draft in progress (GDD 02 section 10; M4-15). `open` while the player (or a bot policy) has to pick:
## `SimWorld.step()` does nothing until `command_pick`. `offers` holds patch indices (rows of `SimConfig.patches`),
## ordered ARMS, CHASSIS, SYSTEMS (R1-04; a family with nothing to offer is skipped or filled from another family);
## `wave` is the wave whose end opened the draft; `rerolls_used` counts `command_reroll` calls of this draft.
## Closed state (all defaults) adds nothing to the hash.

var open: bool = false
var wave: int = 0
var offers: PackedInt32Array = PackedInt32Array()
var rerolls_used: int = 0


func close() -> void:
	open = false
	wave = 0
	offers = PackedInt32Array()
	rerolls_used = 0
