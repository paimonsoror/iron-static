class_name FrameCard
extends RefCounted
## Plain data the frame bay (M3-29), the title and Home bind to, one per listed frame (M3-23). Built by
## `FrameRules.cards`; never mutated by the UI. Text is looked up by key (data/strings_en.csv), never stored.

## Stat keys in display order; the label key of each is `frame.stat.<key>`.
const STAT_KEYS: Array[String] = ["hull", "rate", "damage", "range", "crit", "repair"]

var id: String = ""
var name_key: String = ""  ## frame.name.<id>
var role_key: String = ""  ## frame.role.<id>
var passive_key: String = ""  ## frame.passive.<id>
var passive_desc_key: String = ""  ## frame.passive_desc.<id>
var locked: bool = true
var selected: bool = false
## Lock text: key `frame.locked_wave` with `{n}` = `unlock_best_wave`; progress key `frame.progress` with
## `{n}` = `best_wave`. Both keys are empty for an unlocked frame.
var unlock_best_wave: int = 0
var best_wave: int = 0
var condition_key: String = ""
var progress_key: String = ""
## Percent change of each stat against the reference frame (the selected one), e.g. hull +60.0.
var deltas: Dictionary = {}
## Power Rating of the frame's start stats with the profile's Foundry levels applied (key `frame.pr`).
var power_rating: float = 0.0
## Percent change of the Power Rating against the reference frame (same Foundry levels).
var power_rating_delta: float = 0.0


## Percent delta of a stat key (0.0 for an unknown key).
func delta(key: String) -> float:
	var v: Variant = deltas.get(key, 0.0)
	if v is float:
		var f: float = v
		return f
	return 0.0
