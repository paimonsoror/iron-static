class_name WaveModeDef
extends Resource
## One wave mode row of data/wave_modes.csv (M4-01). Generated; never hand-edit the .tres.
## `backstop_s` 0 = no backstop (the 24 s wave clock rules); `reward_mult` scales per-kill rewards.

@export var id: String = ""
@export var implemented: bool = false
@export var unlock_best_timed_wave: int = 0  ## best TIMED wave needed to unlock; 0 = unlocked from the start
@export var backstop_s: float = 0.0
@export var reward_mult: float = 1.0
@export var sort: int = 0
