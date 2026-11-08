class_name FoundryDef
extends Resource
## One Foundry row of data/foundry.csv (GDD 05 sections 1.1-1.3). Generated; never hand-edit the .tres.
## `kind` "D": `f` is the per-level factor of foundry_mult. "C": `f` is 0 (the step is the run row's step).

@export var id: String = ""
@export var kind: String = ""
@export var f: float = 0.0
@export var f_cap: int = 0
@export var fc0: float = 0.0
@export var fg: float = 0.0
@export var tag: String = ""
