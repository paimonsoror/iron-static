class_name SnapshotFields
extends RefCounted
## State-coverage table of the run snapshot (M3-09). Every script variable of the sim state classes is
## classified here, so adding sim state later fails `test_sim_snapshot` until someone decides how it persists:
##   SAVED   - written by `SimSnapshot.capture` and restored.
##   DERIVED - rebuilt on restore (the note says how).
##   IGNORED - not part of a run's behavior (the note says why).
## Format of each entry: "KIND: note".

const TABLE: Dictionary = {
	"SimWorld":
	{
		"config": "IGNORED: supplied by the caller of restore; sim_version, config_hash and run inputs are checked",
		"tick": "SAVED: scalar",
		"wave": "SAVED: scalar",
		"wave_tick": "SAVED: scalar",
		"level_hp": "SAVED: scalar",
		"level_atk": "SAVED: scalar",
		"enemies": "SAVED: EnemyStore.save_state",
		"projectiles": "SAVED: ProjectileStore.save_state",
		"grid": "DERIVED: grid.rebuild(enemies) after restore",
		"cinder": "SAVED: hp, max_hp, band, alive, invulnerable",
		"stats": "DERIVED: resolve_stats() from run_levels, the config's Foundry arrays and the frame",
		"economy": "SAVED: BigNum mantissa and exponent plus the float shadows",
		"run_levels": "SAVED: packed array",
		"visible": "SAVED: packed array",
		"tick_scrap": "SAVED: scalar",
		"tick_data": "SAVED: scalar",
		"run": "SAVED: every RunStats field",
		"events": "IGNORED: view feed; restore starts an empty ring (the view and audio router are re-bound by M3-13)",
		"plan": "SAVED: WavePlanState fields and arrays",
		"input_log": "SAVED: the four packed arrays (the restored run keeps recording)",
		"rng_spawn": "SAVED: Rng state and increment",
		"rng_crit": "SAVED: Rng state and increment",
		"rng_loot": "SAVED: Rng state and increment",
		"rng_effects": "SAVED: Rng state and increment",
		"rng_draft": "SAVED: Rng state and increment",
		"laser_charge": "SAVED: scalar",
		"next_wave_is_boss": "SAVED: scalar",
		"query_buf": "DERIVED: scratch buffer sized by the constructor, never read across ticks",
		"type_is_boss": "DERIVED: built by the constructor from config.enemies",
		"type_behavior": "DERIVED: built by the constructor from config.enemies",
		"frame_ext": "DERIVED: built by the constructor from config.frame",
		"frame_passive": "DERIVED: built by the constructor from config.frame",
		"frame_scrap_mult": "DERIVED: built by the constructor from config.frame",
		"frame_overclock_scale": "DERIVED: built by the constructor from config.frame",
		"frame_overclock_kill_cap": "DERIVED: built by the constructor from config.frame",
		"frame_data_mult": "DERIVED: built by the constructor from config.frame",
		"overclock_kills": "SAVED: Overclock per-wave counter",
		"_streams": "DERIVED: rebuilt by the constructor, the stream states are saved as rng_*",
		"log_frame_errors": "IGNORED: static test switch",
	},
	"CinderState":
	{
		"hp": "SAVED: float",
		"max_hp": "SAVED: float",
		"band": "SAVED: int",
		"alive": "SAVED: bool",
		"invulnerable": "SAVED: bool",
		"hit_cap_frac": "DERIVED: set by the constructor from the frame passive (Bastion)",
	},
	"RunStats":
	{
		"kills": "SAVED: int",
		"kills_by_type": "SAVED: packed array",
		"scrap_earned": "SAVED: float",
		"data_earned": "SAVED: float",
		"damage_dealt": "SAVED: float",
		"death_wave": "SAVED: int",
		"death_cause": "SAVED: int",
		"spawn_throttled": "SAVED: int",
		"ended": "SAVED: bool",
	},
	"EconomyState":
	{
		"scrap": "SAVED: BigNum mantissa and exponent",
		"data_run": "SAVED: BigNum mantissa and exponent",
		"wave_kill_scrap": "SAVED: float",
		"scrap_frac": "SAVED: float",
		"conversions": "SAVED: int (test counter, kept so capture/restore/capture is byte-identical)",
	},
	"WavePlanState":
	{
		"wave": "SAVED: int",
		"built": "SAVED: bool",
		"count": "SAVED: int",
		"cursor": "SAVED: int",
		"carried": "SAVED: int",
		"dropped_carry": "SAVED: int",
		"dropped_slots": "SAVED: int",
		"type_index": "SAVED: packed array",
		"spawn_tick": "SAVED: packed array",
		"angle_idx": "SAVED: packed array",
		"spawned": "SAVED: packed array",
	},
	"EnemyStore":
	{
		"capacity": "IGNORED: fixed by the config's alive caps; restore checks the saved arrays fit",
		"alive_count": "SAVED: int",
		"high_water": "SAVED: int",
		"alive": "SAVED: array up to high_water",
		"stale": "SAVED: array up to high_water",
		"type_id": "SAVED: array up to high_water",
		"pos_x": "SAVED: array up to high_water",
		"pos_y": "SAVED: array up to high_water",
		"prev_x": "SAVED: array up to high_water",
		"prev_y": "SAVED: array up to high_water",
		"radius": "SAVED: array up to high_water",
		"speed": "SAVED: array up to high_water",
		"hp": "SAVED: array up to high_water",
		"max_hp": "SAVED: array up to high_water",
		"dmg": "SAVED: array up to high_water",
		"spawn_id": "SAVED: array up to high_water",
		"born_wave": "SAVED: array up to high_water",
		"level_hp": "SAVED: array up to high_water",
		"cell": "DERIVED: grid.rebuild writes it for every alive enemy",
		"melee_hits": "SAVED: array up to high_water",
		"next_attack_tick": "SAVED: array up to high_water",
		"_free_list": "SAVED: slice up to the free top",
		"_free_top": "SAVED: int",
		"_next_spawn_id": "SAVED: int",
		"_type_counts": "SAVED: packed array",
	},
	"ProjectileStore":
	{
		"capacity": "IGNORED: fixed constant of the store; restore checks the saved arrays fit",
		"alive_count": "SAVED: int",
		"high_water": "SAVED: int",
		"alive": "SAVED: array up to high_water",
		"pos_x": "SAVED: array up to high_water",
		"pos_y": "SAVED: array up to high_water",
		"vel_x": "SAVED: array up to high_water",
		"vel_y": "SAVED: array up to high_water",
		"damage": "SAVED: array up to high_water",
		"ttl_ticks": "SAVED: array up to high_water",
		"owner_type": "SAVED: array up to high_water",
		"_free_list": "SAVED: slice up to the free top",
		"_free_top": "SAVED: int",
	},
	"Rng":
	{
		"_state": "SAVED: via get_state",
		"_inc": "SAVED: via get_state",
	},
	"InputLog":
	{
		"ticks": "SAVED: packed array",
		"kinds": "SAVED: packed array",
		"arg_a": "SAVED: packed array",
		"arg_b": "SAVED: packed array",
	},
	"SpatialGrid":
	{
		"cells_per_side": "DERIVED: constructor, from the arena radius",
		"cell_size": "DERIVED: constructor",
		"arena_radius": "DERIVED: constructor",
		"cell_head": "DERIVED: grid.rebuild",
		"next_in_cell": "DERIVED: grid.rebuild",
		"_inv_cell": "DERIVED: constructor",
	},
}


## Script variables of `obj` (all script levels) that `class_key` does not classify, or whose entry does not
## start with SAVED, DERIVED or IGNORED. Empty = fully covered.
static func unclassified(obj: Object, class_key: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var entries: Dictionary = TABLE.get(class_key, {})
	for p: Dictionary in obj.get_property_list():
		var usage: int = p["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var prop_name: String = p["name"]
		var note: String = entries.get(prop_name, "")
		if not (note.begins_with("SAVED") or note.begins_with("DERIVED") or note.begins_with("IGNORED")):
			if out.append(prop_name):
				push_error("SnapshotFields: append failed")
	return out
