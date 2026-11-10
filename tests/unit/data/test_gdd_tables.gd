class_name TestGddTables
extends GdUnitTestSuite
## The generated M1 tables hold exactly the GDD numbers (GDD 03 s1.1/s1.3, 02 s7, 08 s1.3) and
## SimConfigLoader hands them to the sim in the contract order.

const ENEMY_IDS: PackedStringArray = ["skitter", "dart", "walker", "lancer", "boss_hulk"]
const UPGRADE_IDS: PackedStringArray = [
	"laser_output",
	"cycle_rate",
	"crit_chance",
	"crit_mult",
	"optic_range",
	"hull_integrity",
	"nano_repair",
	"plating_pct",
	"scrap_yield",
	"reinvest",
]  # gdlint: ignore=max-line-length


func test_default_config_shape() -> void:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	assert_int(cfg.seed_value).is_equal(1)
	assert_int(cfg.sector).is_equal(1)
	assert_str(cfg.ruleset).is_equal("standard")
	assert_bool(cfg.debug_invulnerable).is_false()
	assert_object(cfg.tuning).is_not_null()
	assert_int(cfg.tuning.tick_rate).is_equal(30)
	assert_int(cfg.enemies.size()).is_equal(5)
	assert_int(cfg.upgrades.size()).is_equal(10)
	for i: int in ENEMY_IDS.size():
		assert_str(cfg.enemies[i].id).is_equal(ENEMY_IDS[i])
	for i: int in UPGRADE_IDS.size():
		assert_str(cfg.upgrades[i].id).is_equal(UPGRADE_IDS[i])


func test_loader_returns_independent_copies() -> void:
	var a: SimConfig = SimConfigLoader.load_default(1)
	a.tuning.alive_cap_normal = 5
	a.enemies[0].speed = 99.0
	var b: SimConfig = SimConfigLoader.load_default(2)
	assert_int(b.tuning.alive_cap_normal).is_equal(160)
	assert_float(b.enemies[0].speed).is_equal(3.5)


## [id, group, hp_mult, dmg_mult, speed, radius, slots, scrap_mult, data_base, weight, first_wave, behavior]
func test_enemies_match_gdd_03() -> void:
	var rows: Array = [
		["skitter", "normal", 1.0, 1.0, 3.5, 0.6, 1, 1.0, 1.0, 100.0, 1, "melee"],
		["dart", "normal", 0.8, 0.8, 7.35, 0.5, 1, 1.5, 2.0, 30.0, 4, "melee"],
		["walker", "normal", 5.0, 1.5, 2.1, 1.4, 3, 3.0, 4.0, 18.0, 8, "melee"],
		["lancer", "normal", 1.0, 1.2, 4.2, 0.7, 1, 1.5, 2.0, 22.0, 6, "ranged"],
		["boss_hulk", "boss", 8.0, 3.0, 1.4, 3.0, 1, 5.0, 15.0, 0.0, 10, "melee_boss"],
	]
	var enemies: Array[EnemyDef] = SimConfigLoader.load_default(1).enemies
	for i: int in rows.size():
		var r: Array = rows[i]
		var e: EnemyDef = enemies[i]
		assert_str(e.id).is_equal(r[0])
		assert_str(e.group).is_equal(r[1])
		assert_float(e.hp_mult).is_equal(r[2])
		assert_float(e.dmg_mult).is_equal(r[3])
		assert_float(e.speed).is_equal(r[4])
		assert_float(e.radius).is_equal(r[5])
		assert_int(e.slots).is_equal(r[6])
		assert_float(e.scrap_mult).is_equal(r[7])
		assert_float(e.data_base).is_equal(r[8])
		assert_float(e.spawn_weight).is_equal(r[9])
		assert_int(e.first_wave).is_equal(r[10])
		assert_str(e.behavior_id).is_equal(r[11])
		assert_str(e.tag).is_equal("MVP")
		assert_str(e.shape).is_equal(r[0])


## [id, tab, kind, base, step, l_cap, hard_cap (-1 = none), c0, g, gate]
func test_upgrades_match_gdd_02() -> void:
	var rows: Array = [
		["laser_output", "arms", "D", 10.0, 0.10, 400, -1.0, 10.0, 1.108, 0],
		["cycle_rate", "arms", "C", 1.0, 0.04, 100, 12.0, 25.0, 1.12, 0],
		["crit_chance", "arms", "C", 0.02, 0.008, 98, 0.85, 60.0, 1.10, 5],
		["crit_mult", "arms", "C", 1.5, 0.05, 150, -1.0, 80.0, 1.085, 8],
		["optic_range", "arms", "C", 24.0, 0.4, 100, 80.0, 40.0, 1.10, 10],
		["hull_integrity", "chassis", "D", 100.0, 0.10, 400, -1.0, 10.0, 1.108, 0],
		["nano_repair", "chassis", "D", 1.0, 0.60, 400, -1.0, 20.0, 1.09, 0],
		["plating_pct", "chassis", "C", 0.0, 0.06, 99, 0.90, 20.0, 1.10, 10],
		["scrap_yield", "systems", "C", 1.0, 0.02, 100, 3.0, 50.0, 1.10, 3],
		["reinvest", "systems", "C", 0.0, 0.0006, 99, 0.0594, 300.0, 1.11, 12],
	]
	var ups: Array[RunUpgradeDef] = SimConfigLoader.load_default(1).upgrades
	for i: int in rows.size():
		var r: Array = rows[i]
		var u: RunUpgradeDef = ups[i]
		assert_str(u.id).is_equal(r[0])
		assert_str(u.tab).is_equal(r[1])
		assert_str(u.kind).is_equal(r[2])
		assert_float(u.base).is_equal(r[3])
		assert_float(u.step).is_equal(r[4])
		assert_int(u.l_cap).is_equal(r[5])
		var cap: float = r[6]
		assert_bool(u.has_hard_cap).is_equal(cap >= 0.0)
		if cap >= 0.0:
			assert_float(u.hard_cap).is_equal(cap)
		assert_float(u.c0).is_equal(r[7])
		assert_float(u.g).is_equal(r[8])
		assert_int(u.gate_best_wave).is_equal(r[9])


func test_sim_constants_spot_values() -> void:
	var t: SimTuning = SimConfigLoader.load_default(1).tuning
	assert_float(t.g_hp_1).is_equal(1.063)
	assert_int(t.alive_cap_normal).is_equal(160)
	assert_float(t.exposure_hysteresis).is_equal(0.05)
	assert_float(t.lancer_bolt_speed).is_equal(18.0)
	assert_float(t.arena_radius).is_equal(52.0)
	assert_int(t.boss_interval).is_equal(10)
	assert_float(t.hp0).is_equal(14.0)
	assert_int(t.wave_seconds).is_equal(t.spawn_seconds + t.lull_seconds)


func test_foundry_multiplier_table_gdd_05_s1_2() -> void:
	# GDD 05 s1.2 (FO-3): (1 + f*F) * 1.75^floor(F/25), hull f from the generated Foundry table.
	var hull: FoundryDef = FoundryRules.find_def(SimConfigLoader.load_foundry_defs(), "hull_integrity")
	var table: Dictionary = {25: 4.4, 50: 12.3, 100: 65.7, 200: 1143.0}
	for level: int in table.keys():
		var want: float = table[level]
		assert_float(FoundryRules.multiplier(hull, level)).is_equal_approx(want, want * 0.01)
