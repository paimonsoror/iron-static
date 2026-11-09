class_name ModeCard
extends RefCounted
## Plain data the Home mode picker (M4-08) and Results bind to, one per listed wave mode (M4-07). Built by
## `ModeRules.cards`; never mutated by the UI.

var id: String = ""
var name_key: String = ""  ## mode.<id>
var desc_key: String = ""  ## mode.<id>.desc
var unlocked: bool = true
## Best TIMED wave needed to unlock (data/wave_modes.csv); 0 = open from the start.
var unlock_wave: int = 0
## This mode's own best wave in sector 1 (0 when never played).
var best: int = 0
var selected: bool = false
## Text of a locked card: "Reach wave {n} in TIMED to unlock" (key `mode.locked`, n = `unlock_wave`).
## Empty when unlocked.
var locked_text: String = ""
## Text of a locked card: "Best TIMED wave: {n}" (key `mode.progress`, n = the TIMED best). Empty when unlocked.
var progress_text: String = ""
