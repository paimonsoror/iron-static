class_name TestPatchEffects
extends GdUnitTestSuite
## Patch effects in the stat pipeline (M4-14): every patch with 0, 1 and max picks against its table formula.

const TABLE_PATH: String = "res://src/data_gen/patch_table.tres"
const LEVEL: int = 7  ## run level of every upgrade row, so base values are not all level-0 constants
const EPS: float = 1.0e-9
const STATS: PackedStringArray = [
	"laser_output",
	"hull_integrity",
	"cycle_rate",
	"scrap_yield",
	"nano_repair",
	"plating_pct",
	"data_yield",
	"enemy_damage",
]


static func cfg_with_patches(seed_value: int = 3) -> SimConfig:
	var cfg: SimConfig = SimConfigLoader.load_default(seed_value)
	var table: PatchTable = load(TABLE_PATH)
	for d: PatchDef in table.defs:
		var copy: Variant = SimConfigLoader._clone(d)
		cfg.patches.append(copy)
	return cfg


func _world() -> SimWorld:
	var w: SimWorld = SimWorld.new(cfg_with_patches())
	w.run_levels.fill(LEVEL)
	w.stats = w.resolve_stats()
	return w


func _index(w: SimWorld, id: String) -> int:
	for i: int in w.config.patches.size():
		if w.config.patches[i].id == id:
			return i
	return -1


func _stat(s: StatBlock, id: String) -> float:
	var table: Dictionary = {
		"laser_output": s.laser_output,
		"hull_integrity": s.hull_integrity,
		"cycle_rate": s.cycle_rate,
		"scrap_yield": s.scrap_yield,
		"nano_repair": s.nano_repair,
		"plating_pct": s.plating_pct,
		"data_yield": s.data_yield,
		"enemy_damage": s.enemy_damage,
	}
	var v: float = table[id]
	return v


func _with_picks(w: SimWorld, picks: Dictionary) -> StatBlock:
	var v: PackedInt32Array = PackedInt32Array()
	assert_int(v.resize(w.config.patches.size())).is_equal(OK)
	v.fill(0)
	for id: String in picks:
		v[_index(w, id)] = picks[id]
	w.patches.set_picks(v)
	return w.resolve_stats()


## `factors`: stat id to the multiplier at `qty` picks; `adds`: stat id to the additive points at `qty`.
## Every stat not named must equal the no-pick value.
func _expect(id: String, qty: int, factors: Dictionary, adds: Dictionary = {}) -> void:
	var w: SimWorld = _world()
	var base: StatBlock = _with_picks(w, {})
	var got: StatBlock = _with_picks(w, {id: qty})
	for s: String in STATS:
		var want: float = _stat(base, s)
		if factors.has(s):
			var f: float = factors[s]
			want *= f
		if adds.has(s):
			var a: float = adds[s]
			want = minf(want + a, 0.90)  # plating_pct hard cap
		assert_float(_stat(got, s)).override_failure_message("%s x%d: %s" % [id, qty, s]).is_equal_approx(want, EPS)


func _each_qty(id: String, max_picks: int, factor_fn: Callable) -> void:
	for q: int in [0, 1, max_picks]:
		var fx: Array = factor_fn.call(q)
		var factors: Dictionary = fx[0]
		var adds: Dictionary = fx[1]
		_expect(id, q, factors, adds)


func test_overcharge() -> void:
	_each_qty("patch_overcharge", 5, func(q: int) -> Array: return [{"laser_output": 1.0 + 0.09 * q}, {}])


func test_plating() -> void:
	_each_qty("patch_plating", 5, func(q: int) -> Array: return [{"hull_integrity": 1.0 + 0.12 * q}, {}])


func test_rate() -> void:
	_each_qty("patch_rate", 5, func(q: int) -> Array: return [{"cycle_rate": 1.0 + 0.06 * q}, {}])


func test_extraction() -> void:
	_each_qty(
		"patch_extraction",
		5,
		func(q: int) -> Array: return [{"scrap_yield": 1.0 + 0.09 * q, "data_yield": 1.0 + 0.09 * q}, {}]
	)


func test_regen() -> void:
	_each_qty("patch_regen", 5, func(q: int) -> Array: return [{"nano_repair": 1.0 + 0.30 * q}, {}])


func test_ceramic() -> void:
	_each_qty("patch_ceramic", 5, func(q: int) -> Array: return [{}, {"plating_pct": 0.025 * q}])
	var w: SimWorld = SimWorld.new(cfg_with_patches())  # level 0: plating_pct base is 0
	assert_float(_with_picks(w, {"patch_ceramic": 5}).plating_pct).is_equal_approx(0.125, EPS)


func test_glass_applies_benefit_and_cost() -> void:
	_each_qty(
		"patch_t_glass",
		1,
		func(q: int) -> Array: return [{"laser_output": pow(1.35, q), "hull_integrity": pow(0.70, q)}, {}]
	)


func test_greed() -> void:
	_each_qty(
		"patch_t_greed",
		1,
		func(q: int) -> Array: return [{"data_yield": pow(1.5, q), "hull_integrity": pow(0.50, q)}, {}]
	)


func test_hardhide() -> void:
	_each_qty(
		"patch_t_hardhide",
		1,
		func(q: int) -> Array: return [{"enemy_damage": pow(0.60, q), "laser_output": pow(0.60, q)}, {}]
	)


func test_two_patches_stack_after_run_levels_and_with_the_frame() -> void:
	var cfg: SimConfig = cfg_with_patches()
	var frame: FrameMods = FrameMods.new()
	frame.laser_mult = 0.9
	cfg.frame = frame
	cfg.frame_id = "test"
	var w: SimWorld = SimWorld.new(cfg)
	w.run_levels.fill(LEVEL)
	var base: StatBlock = _with_picks(w, {})
	var got: StatBlock = _with_picks(w, {"patch_overcharge": 2, "patch_t_glass": 1, "patch_t_hardhide": 1})
	var want: float = base.laser_output * (1.0 + 0.18) * 1.35 * 0.60
	assert_float(got.laser_output).is_equal_approx(want, EPS)
	assert_float(got.hull_integrity).is_equal_approx(base.hull_integrity * 0.70, EPS)
	assert_float(got.enemy_damage).is_equal_approx(0.60, EPS)


func test_no_picks_leaves_stats_and_hash_untouched() -> void:
	var plain: SimWorld = SimWorld.new(SimConfigLoader.load_default(3))
	var w: SimWorld = SimWorld.new(cfg_with_patches())
	assert_str(w.state_hash()).is_equal(plain.state_hash())
	assert_float(w.stats.data_yield).is_equal(1.0)
	assert_float(w.stats.enemy_damage).is_equal(1.0)
	assert_object(PatchEffects.compose(null, w.patches, w.config.patches)).is_null()
	assert_bool(PatchEffects.pick(w, _index(w, "patch_overcharge"))).is_true()
	assert_str(w.state_hash()).is_not_equal(plain.state_hash())


func test_pick_moves_the_hull_and_respects_max_picks() -> void:
	var w: SimWorld = SimWorld.new(cfg_with_patches())
	var hull: float = w.cinder.max_hp
	assert_bool(PatchEffects.pick(w, _index(w, "patch_t_glass"))).is_true()
	assert_float(w.cinder.max_hp).is_equal_approx(hull * 0.70, EPS)
	assert_float(w.cinder.hp).is_equal_approx(hull * 0.70, EPS)
	assert_bool(PatchEffects.pick(w, _index(w, "patch_t_glass"))).is_false()
	assert_int(w.patches.total_picks).is_equal(1)
	assert_bool(PatchEffects.pick(w, 99)).is_false()
	assert_bool(PatchEffects.pick(w, _index(w, "patch_plating"))).is_true()
	assert_float(w.cinder.max_hp).is_equal_approx(hull * 0.70 * 1.12, EPS)


func test_greed_scales_the_kill_data_reward() -> void:
	var plain: SimWorld = SimWorld.new(cfg_with_patches())
	var greedy: SimWorld = SimWorld.new(cfg_with_patches())
	assert_bool(PatchEffects.pick(greedy, _index(greedy, "patch_t_greed"))).is_true()
	for w: SimWorld in [plain, greedy]:
		w.config.tuning.alive_cap_normal = 0  # no wave spawns; only the debug enemy exists
		assert_int(w.debug_spawn_enemy(0, 3.0, 0.0)).is_greater_equal(0)
		for t: int in 200:
			w.step()
	assert_int(plain.run.kills).is_equal(1)
	assert_int(greedy.run.kills).is_equal(1)
	assert_float(greedy.run.data_earned).is_equal_approx(plain.run.data_earned * 1.5, 1.0e-6)


func test_hardhide_scales_melee_damage() -> void:
	var taken: Array[float] = []
	for pick: bool in [false, true]:
		var w: SimWorld = SimWorld.new(cfg_with_patches())
		if pick:
			assert_bool(PatchEffects.pick(w, _index(w, "patch_t_hardhide"))).is_true()
		var i: int = w.debug_spawn_enemy(0, 0.0, 0.0)
		var hp: float = w.cinder.hp
		w.enemies.next_attack_tick[i] = 0
		w.enemies.hp[i] = 1.0e9
		EnemyAttackSystem.step(w)
		taken.append(hp - w.cinder.hp)
	assert_float(taken[0]).is_greater(0.0)
	assert_float(taken[1]).is_equal_approx(taken[0] * 0.60, 1.0e-9)
