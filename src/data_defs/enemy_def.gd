class_name EnemyDef
extends Resource
## One enemy type row of data/enemies.csv (GDD 03 section 1). Generated into src/data_gen/ by the
## importer; never hand-edit the .tres. Numbers come from the CSV, defaults here are placeholders.

@export var id: String = ""
@export var group: String = ""
@export var shape: String = ""
@export var hp_mult: float = 0.0
@export var dmg_mult: float = 0.0
@export var speed: float = 0.0  ## meters per second
@export var radius: float = 0.0  ## meters
@export var slots: int = 0  ## spawn budget cost
@export var scrap_mult: float = 0.0
@export var data_base: float = 0.0
@export var spawn_weight: float = 0.0
@export var first_wave: int = 0
@export var behavior_id: String = ""  ## melee, ranged, melee_boss
@export var tag: String = ""
