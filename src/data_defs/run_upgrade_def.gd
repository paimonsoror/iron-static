class_name RunUpgradeDef
extends Resource
## One in-run upgrade row of data/run_upgrades.csv (GDD 02 section 7). Generated; never hand-edit the .tres.
## `kind` "D" = doubling-style row (`step` is the factor p of the D formula), "C" = linear row
## (`step` is the per-level increment). `has_hard_cap` is false when the CSV hard_cap is empty.

@export var id: String = ""
@export var tab: String = ""  ## arms, chassis, systems
@export var kind: String = ""
@export var base: float = 0.0
@export var step: float = 0.0
@export var l_cap: int = 0
@export var has_hard_cap: bool = false
@export var hard_cap: float = 0.0
@export var c0: float = 0.0
@export var g: float = 0.0
@export var gate_best_wave: int = 0
@export var tag: String = ""
