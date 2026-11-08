class_name SimTuning
extends Resource
## Every simulation tunable from data/sim_constants.csv, one typed var per key. The importer maps CSV
## keys to the vars declared here (unknown or missing keys fail), so adding a tunable means adding a
## var here plus a CSV row. Defaults are zero placeholders: real values live only in the CSV.

# Time and arena (GDD 02 sections 2, 6)
var tick_rate: int = 0
var wave_seconds: int = 0
var spawn_seconds: int = 0
var lull_seconds: int = 0
var arena_radius: float = 0.0
var cinder_radius: float = 0.0

# Melee (GDD 02 section 6, 03 section 1.1)
var melee_range: float = 0.0
var melee_interval_s: float = 0.0
var bite_gain: float = 0.0
var bite_cap: float = 0.0

# Enemy scaling (GDD 03 sections 2, 4)
var hp0: float = 0.0
var d0: float = 0.0
var g_hp_1: float = 0.0
var g_hp_2: float = 0.0
var g_hp_3: float = 0.0
var g_atk_1: float = 0.0
var g_atk_2: float = 0.0
var g_atk_3: float = 0.0
var phase_1_end: int = 0
var phase_2_end: int = 0
var sector_offset_step: int = 0

# Spawn count and composition (GDD 02 section 6, 03 sections 4.4, 5, 7)
var n_base: float = 0.0
var n_coef: float = 0.0
var n_exp: float = 0.0
var n_cap: int = 0
var boss_interval: int = 0
var boss_slot_fraction: float = 0.0
var boss_spawn_s: float = 0.0
var flank_fraction: float = 0.0
var flank_min: int = 0
var flank_max: int = 0
var flank_half_angle_deg: float = 0.0
var ramp_waves: int = 0
var slot_overflow: int = 0
var reject_limit: int = 0

# Caps and stale rule (GDD 02 sections 2, 6)
var alive_cap_normal: int = 0
var alive_cap_boss: int = 0
var stale_wave_ends: int = 0
var stale_payout: float = 0.0

# Rewards (GDD 03 section 3, 02 section 7.4)
var scrap_k: float = 0.0
var scrap_exp: float = 0.0
var data_level_coef: float = 0.0
var reward_growth: float = 0.0
var start_scrap: float = 0.0

# Lancer (GDD 03 section 1.1)
var lancer_range_min: float = 0.0
var lancer_range_factor: float = 0.0
var lancer_range_cap: float = 0.0
var lancer_fire_s: float = 0.0
var lancer_bolt_speed: float = 0.0

# Intake and exposure (GDD 02 sections 12, 12.1)
var plating_pct_cap: float = 0.0
var min_damage_floor: float = 0.0
var exposure_t1: float = 0.0
var exposure_t2: float = 0.0
var exposure_t3: float = 0.0
var exposure_hysteresis: float = 0.0
