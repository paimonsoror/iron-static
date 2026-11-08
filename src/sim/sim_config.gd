class_name SimConfig
extends RefCounted
## Plain typed holder for everything a SimWorld is built from (M1 shared contract). Created by
## SimConfigLoader (src/core) from the generated data; tests may build one by hand.

var seed_value: int = 0
var sector: int = 1
var tuning: SimTuning = null
var enemies: Array[EnemyDef] = []
var upgrades: Array[RunUpgradeDef] = []
var ruleset: String = "standard"
var debug_invulnerable: bool = false
