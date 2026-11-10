class_name FoundryRowView
extends RefCounted
## Plain data the Foundry UI and Results/Home bind to, one per Foundry row (M3-06). Built by
## `FoundryService.rows`; never mutated by the UI.

var id: String = ""
var kind: String = ""  ## "D" or "C"
var level: int = 0
var cap: int = 0
var maxed: bool = false
## Soft cap (R1-02, replaced the FO-3 hard cap): `limit` is the level from which a purchase costs `over_mult` times more
## (`FoundryRules.wave_cap` at the best wave); `over_limit` means the next level is at or above it, so `cost` already
## includes the multiplier; `next_wave` is the smallest best wave at which the next level is back at the normal price
## (0 when not over the limit); `room_below_limit` is how many levels can still be bought at the normal price
## (0 when over the limit); `base_cost` is the next level cost without the multiplier. `level` is never lowered
## below what the profile owns. The row is never locked.
var limit: int = 0
var over_limit: bool = false
var over_mult: float = 1.0
var next_wave: int = 0
var room_below_limit: int = 0
var base_cost: BigNum = BigNum.zero()
## Cost of the next level, with the over-limit multiplier when `over_limit` (zero when maxed).
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
## The Foundry milestone of the tuning (`foundry_milestone_step` / `foundry_milestone_mult`), for texts.
var milestone_step: int = 0
var milestone_mult: float = 1.0
## Levels until the next x1.75 milestone (Type D); -1 for Type C and for maxed rows.
var levels_to_milestone: int = -1
## Game minutes at 1x until the next level is affordable: 0 when affordable now, -1 when unknown (no farm
## rate yet) or maxed.
var afford_in_minutes: float = -1.0
