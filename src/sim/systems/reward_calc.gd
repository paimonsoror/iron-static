class_name RewardCalc
extends RefCounted
## Pure kill-reward helper (GDD 03 section 3). Also used by WaveEnd tests and M2.
##   scrap = max(1, round(k * G_hp(l)^exp)) * scrap_mult * scrap_yield
##   data  = data_base * (1 + coef * l) * R(s)
## Stale enemies pay `stale_payout` (0.5) of both.


## `level` is the enemy health level at spawn (incl. sector offset).
static func scrap_for_kill(t: SimTuning, def: EnemyDef, level: int, scrap_yield: float, stale: bool) -> float:
	var g: float = Curves.g_growth(level, t.g_hp_1, t.g_hp_2, t.g_hp_3, t.phase_1_end, t.phase_2_end)
	var v: float = float(Curves.scrap_per_kill_base(g, t.scrap_k, t.scrap_exp)) * def.scrap_mult * scrap_yield
	return v * t.stale_payout if stale else v


static func data_for_kill(t: SimTuning, def: EnemyDef, level: int, sector: int, stale: bool) -> float:
	var v: float = Curves.data_per_kill_base(
		def.data_base, level, t.data_level_coef, Curves.sector_reward(sector, t.reward_growth)
	)
	return v * t.stale_payout if stale else v
