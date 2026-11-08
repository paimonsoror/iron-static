class_name RunStats
extends RefCounted
## Per-run counters (M1 shared contract). All fields are part of `state_hash()`.

var kills: int = 0
## Kills per enemy type index (sized EnemyStore.MAX_TYPES).
var kills_by_type: PackedInt32Array
var scrap_earned: float = 0.0
var data_earned: float = 0.0
var damage_dealt: float = 0.0
## Wave in which Cinder died; 0 while the run is alive.
var death_wave: int = 0
## Enemy type index of the killer, -1 none. Set by whoever applies the lethal hit.
var death_cause: int = -1
## Spawns delayed by the alive caps (counted once per throttled tick; M1-08).
var spawn_throttled: int = 0
## True once the run has ended (set only by SimWorld.end_run()).
var ended: bool = false


func _init() -> void:
	kills_by_type = PackedInt32Array()
	if kills_by_type.resize(EnemyStore.MAX_TYPES) != OK:
		push_error("RunStats: resize failed")
