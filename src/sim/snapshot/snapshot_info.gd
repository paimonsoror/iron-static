class_name SnapshotInfo
extends RefCounted
## Header of a run snapshot, readable without rebuilding the world (`SimSnapshot.peek`, M3-09). M3-13 uses it
## to bank `data_run` and show "RUN ENDED BY UPDATE" when `sim_version` or `config_hash` no longer match.

var format: int = 0
var sim_version: int = 0
var config_hash: String = ""
var seed_value: int = 0
var run_id: int = -1
var tick: int = 0
var wave: int = 1
var data_run: String = "0"  ## BigNum text (to_text), banked value of the interrupted run
var frame_id: String = "vanguard"
var sector: int = 1
var best_wave_s1: int = 0
var ruleset: String = "standard"
var wave_mode: String = "timed"  ## M4-05: absent in pre-M4 snapshots = timed
var debug_invulnerable: bool = false
