class_name RunUpgradeDef
extends Resource
## One in-run upgrade row of data/run_upgrades.csv (GDD 02 section 7). Generated; never hand-edit the .tres.
## `kind` "D" = doubling-style row (`step` is the factor p of the D formula), "C" = linear row
## (`step` is the per-level increment). `has_hard_cap` is false when the CSV hard_cap is empty.

var id: String = ""
var tab: String = ""  ## arms, chassis, systems
var kind: String = ""
var base: float = 0.0
var step: float = 0.0
var l_cap: int = 0
var has_hard_cap: bool = false
var hard_cap: float = 0.0
var c0: float = 0.0
var g: float = 0.0
var gate_best_wave: int = 0
var tag: String = ""
