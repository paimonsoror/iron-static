class_name FrameDef
extends Resource
## One Cinder frame row of data/frames.csv (design 11 section 1.2). Generated; never hand-edit the .tres.
## Neutral values are 1.0 (multipliers) and 0 (adds). `implemented` false rows (M6) are never run or listed.

@export var id: String = ""
@export var name_key: String = ""
@export var role_key: String = ""
@export var passive_key: String = ""
@export var unlock_best_wave: int = 0
@export var implemented: bool = false
@export var hull_mult: float = 1.0
@export var plating_add: float = 0.0
@export var nano_mult: float = 1.0
@export var cycle_mult: float = 1.0
@export var optic_mult: float = 1.0
@export var laser_mult: float = 1.0
@export var crit_add: float = 0.0
@export var crit_mult_mult: float = 1.0
@export var scrap_mult: float = 1.0
@export var data_mult: float = 1.0
@export var passive: String = "none"  ## none, bastion, overclock, scrap_tithe, first_sight
@export var bastion_cap_frac: float = 0.20  ## Bastion: max share of max hull one hit may take
@export var overclock_per_kill: float = 0.01  ## Overclock: fire-rate bonus per kill this wave
@export var overclock_cap: float = 0.20  ## Overclock: total bonus cap
@export var tag: String = ""
