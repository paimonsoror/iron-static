class_name EnemyDef
extends Resource
## One enemy type row of data/enemies.csv (GDD 03 section 1). Generated into src/data_gen/ by the
## importer; never hand-edit the .tres. Numbers come from the CSV, defaults here are placeholders.

var id: String = ""
var group: String = ""
var shape: String = ""
var hp_mult: float = 0.0
var dmg_mult: float = 0.0
var speed: float = 0.0  ## meters per second
var radius: float = 0.0  ## meters
var slots: int = 0  ## spawn budget cost
var scrap_mult: float = 0.0
var data_base: float = 0.0
var spawn_weight: float = 0.0
var first_wave: int = 0
var behavior_id: String = ""  ## melee, ranged, melee_boss
var tag: String = ""
