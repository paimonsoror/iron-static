class_name SimConfig
extends RefCounted
## Plain typed holder for everything a SimWorld is built from (M1 shared contract). Created by
## SimConfigLoader (src/core) from the generated data; tests may build one by hand.

const MODE_TIMED: String = "timed"
const MODE_PURGE: String = "purge"

var seed_value: int = 0
var sector: int = 1
var tuning: SimTuning = null
var enemies: Array[EnemyDef] = []
var upgrades: Array[RunUpgradeDef] = []
var ruleset: String = "standard"
var debug_invulnerable: bool = false
## Best wave reached in sector 1; gates which upgrade rows are visible (M2-04/06).
var best_wave_s1: int = 0
## Permanent Foundry levels per `upgrades` row (M3-07). Aligned with `upgrades`; empty = all zero, which keeps
## every hash identical to pre-M3. `foundry_f[i]` is the Type D per-level factor f of row i.
var foundry_levels: PackedInt32Array = PackedInt32Array()
var foundry_f: PackedFloat64Array = PackedFloat64Array()
## Cinder frame (M3-22): null or neutral = VANGUARD (identical to pre-frame). `frame_id` is recorded.
var frame: FrameMods = null
var frame_id: String = "vanguard"
## Wave mode (M4-02, Q76): "timed" or "purge". The sim reads only these three fields, never the CSV.
## `purge_backstop_ticks` 0 = no backstop; `reward_mult` is carried (applied from a later task).
var wave_mode: String = MODE_TIMED
var purge_backstop_ticks: int = 0
var reward_mult: float = 1.0
