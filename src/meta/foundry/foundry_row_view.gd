class_name FoundryRowView
extends RefCounted
## Plain data the Foundry UI and Results/Home bind to, one per Foundry row (M3-06). Built by
## `FoundryService.rows`; never mutated by the UI.

var id: String = ""
var kind: String = ""  ## "D" or "C"
var level: int = 0
var cap: int = 0
var maxed: bool = false
## Cost of the next level (zero when maxed).
var cost: BigNum = BigNum.zero()
## Foundry multiplier now / after one more level (Type D); for Type C the starting stat delta `step * F`.
var mult_now: float = 1.0
var mult_next: float = 1.0
## Stat value a run starts with (run level 0, no frame) now / after one more level, and their difference.
var start_now: float = 0.0
var start_next: float = 0.0
var delta: float = 0.0
var affordable: bool = false
var recommended: bool = false
## Levels until the next x1.25 milestone (Type D); -1 for Type C and for maxed rows.
var levels_to_milestone: int = -1
## Game minutes at 1x until the next level is affordable: 0 when affordable now, -1 when unknown (no farm
## rate yet) or maxed.
var afford_in_minutes: float = -1.0
