class_name UpgradePreview
extends RefCounted
## Read-only result of `UpgradeSystem.preview` (M2-06). The UI and the bot read it; nothing is mutated.
## `levels` is what a buy of `requested` would give now (affordable, capped by `l_cap`). When it is 0 and
## the row is not maxed, `cost` and `next_value` describe one more level so the button can show the price.

var index: int = -1
var requested: int = 0  ## the buy mode asked for: 1, 10, 100 or -1 (Max)
var level: int = 0  ## current level
var levels: int = 0  ## levels a buy would give now
var cost: BigNum = null  ## total cost of `levels` (or of one level when `levels` is 0); zero when maxed
var current_value: float = 0.0
var next_value: float = 0.0  ## value after `levels` (or after one level when `levels` is 0)
var affordable: bool = false  ## levels > 0
var maxed: bool = false  ## level at `l_cap`
var visible: bool = false
var levels_to_milestone: int = 25  ## distance to the next x1.5 milestone level (StatResolver)
