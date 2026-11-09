class_name SimTuning
extends Resource
## Every simulation tunable from data/sim_constants.csv, one typed var per key. The importer maps CSV
## keys to the vars declared here (unknown or missing keys fail), so adding a tunable means adding a
## var here plus a CSV row. Defaults are zero placeholders: real values live only in the CSV.

# Time and arena (GDD 02 sections 2, 6)
@export var tick_rate: int = 0
@export var wave_seconds: int = 0
@export var spawn_seconds: int = 0
@export var lull_seconds: int = 0
@export var arena_radius: float = 0.0
@export var cinder_radius: float = 0.0

# Melee (GDD 02 section 6, 03 section 1.1)
@export var melee_range: float = 0.0
@export var melee_interval_s: float = 0.0
@export var bite_gain: float = 0.0
@export var bite_cap: float = 0.0

# Enemy scaling (GDD 03 sections 2, 4)
@export var hp0: float = 0.0
@export var d0: float = 0.0
@export var g_hp_1: float = 0.0
@export var g_hp_2: float = 0.0
@export var g_hp_3: float = 0.0
@export var g_atk_1: float = 0.0
@export var g_atk_2: float = 0.0
@export var g_atk_3: float = 0.0
@export var phase_1_end: int = 0
@export var phase_2_end: int = 0
@export var sector_offset_step: int = 0

# Spawn count and composition (GDD 02 section 6, 03 sections 4.4, 5, 7)
@export var n_base: float = 0.0
@export var n_coef: float = 0.0
@export var n_exp: float = 0.0
@export var n_cap: int = 0
@export var boss_interval: int = 0
@export var boss_slot_fraction: float = 0.0
@export var boss_spawn_s: float = 0.0
@export var flank_fraction: float = 0.0
@export var flank_min: int = 0
@export var flank_max: int = 0
@export var flank_half_angle_deg: float = 0.0
@export var ramp_waves: int = 0
@export var slot_overflow: int = 0
@export var reject_limit: int = 0

# Caps and stale rule (GDD 02 sections 2, 6)
@export var alive_cap_normal: int = 0
@export var alive_cap_boss: int = 0
@export var stale_wave_ends: int = 0
@export var stale_payout: float = 0.0

# Rewards (GDD 03 section 3, 02 section 7.4)
@export var scrap_k: float = 0.0
@export var scrap_exp: float = 0.0
@export var data_level_coef: float = 0.0
@export var reward_growth: float = 0.0
@export var start_scrap: float = 0.0

# Lancer (GDD 03 section 1.1)
@export var lancer_range_min: float = 0.0
@export var lancer_range_factor: float = 0.0
@export var lancer_range_cap: float = 0.0
@export var lancer_fire_s: float = 0.0
@export var lancer_bolt_speed: float = 0.0

# Intake and exposure (GDD 02 sections 12, 12.1)
@export var plating_pct_cap: float = 0.0
@export var min_damage_floor: float = 0.0
@export var exposure_t1: float = 0.0
@export var exposure_t2: float = 0.0
@export var exposure_t3: float = 0.0
@export var exposure_hysteresis: float = 0.0

# Patch draft (GDD 02 section 10; M4-13, used by the draft system from M4-15)
@export var draft_first_wave: int = 0
@export var draft_interval: int = 0
@export var draft_interval_after: int = 0
@export var draft_interval_late: int = 0
@export var draft_offer_count: int = 0
@export var draft_mix_standard: float = 0.0
@export var draft_mix_gamble: float = 0.0
