class_name TestUpgradeSystem
extends GdUnitTestSuite
## UpgradeSystem buying and previews (M2-06).


func _world(best_wave: int = 0) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.best_wave_s1 = best_wave
	return SimWorld.new(cfg)


func _row(w: SimWorld, id: String) -> int:
	for i: int in w.config.upgrades.size():
		if w.config.upgrades[i].id == id:
			return i
	return -1


func test_laser_output_first_buy_then_second_fails() -> void:
	var w: SimWorld = _world()
	w.economy.scrap = BigNum.from_int(20)  # start scrap is 60 since SimVersion 2; keep the 20-scrap case
	var i: int = _row(w, "laser_output")
	assert_int(w.command_buy(i, 1)).is_equal(1)
	assert_float(w.stats.laser_output).is_equal_approx(11.0, 1.0e-9)
	assert_float(w.economy.scrap.to_float()).is_equal_approx(10.0, 1.0e-6)
	var before: String = w.state_hash()
	assert_int(w.command_buy(i, 1)).is_equal(0)  # costs ceil(10 * 1.108) = 12
	assert_str(w.state_hash()).is_equal(before)


func test_x10_costs_exact_sequential_sum_for_3_rows_and_3_levels() -> void:
	for id: String in ["laser_output", "cycle_rate", "hull_integrity"]:
		for start: int in [0, 7, 40]:
			var w: SimWorld = _world()
			var i: int = _row(w, id)
			var def: RunUpgradeDef = w.config.upgrades[i]
			w.run_levels[i] = start
			w.economy.scrap = BigNum.from_float(1.0e9)
			var expected: float = 0.0
			for k: int in 10:
				expected += ceil(def.c0 * pow(def.g, float(start + k)))
			assert_int(w.command_buy(i, 10)).is_equal(10)
			assert_int(w.run_levels[i]).is_equal(start + 10)
			assert_float(w.economy.scrap.to_float()).is_equal_approx(1.0e9 - expected, 0.5)


func test_partial_x10_buys_what_is_affordable() -> void:
	var w: SimWorld = _world()
	var i: int = _row(w, "laser_output")
	var def: RunUpgradeDef = w.config.upgrades[i]
	w.economy.scrap = BigNum.from_float(Curves.sum_cost(def.c0, def.g, 0, 6) + 1.0)
	assert_int(w.command_buy(i, 10)).is_equal(6)
	assert_float(w.economy.scrap.to_float()).is_equal_approx(1.0, 1.0e-6)


func test_max_stops_at_l_cap() -> void:
	var w: SimWorld = _world()
	var i: int = _row(w, "laser_output")
	w.economy.scrap = BigNum.parse("1e30")
	assert_int(w.command_buy(i, -1)).is_equal(w.config.upgrades[i].l_cap)
	assert_int(w.command_buy(i, 1)).is_equal(0)
	assert_bool(UpgradeSystem.preview(w, i, 1).maxed).is_true()


func test_locked_row_cannot_be_bought_and_unlocks_with_best_wave() -> void:
	var w: SimWorld = _world(0)
	var i: int = _row(w, "crit_chance")
	w.economy.scrap = BigNum.from_float(1.0e6)
	assert_int(w.command_buy(i, 1)).is_equal(0)
	assert_int(w.run_levels[i]).is_equal(0)
	var w2: SimWorld = _world(12)
	w2.economy.scrap = BigNum.from_float(1.0e6)
	assert_int(w2.command_buy(_row(w2, "crit_chance"), 1)).is_equal(1)


func test_purchase_event_carries_new_level() -> void:
	var w: SimWorld = _world()
	var i: int = _row(w, "laser_output")
	w.economy.scrap = BigNum.from_float(1000.0)
	assert_int(w.command_buy(i, 10)).is_equal(10)
	var out: PackedInt32Array = PackedInt32Array()
	assert_int(out.resize(SimEvents.CAPACITY * SimEvents.FIELDS)).is_equal(OK)
	var n: int = w.events.drain(0, out)
	var found: bool = false
	for k: int in n:
		if out[k * SimEvents.FIELDS + 1] == SimEventKind.UPGRADE_BOUGHT:
			found = true
			assert_int(out[k * SimEvents.FIELDS + 2]).is_equal(i)
			assert_int(out[k * SimEvents.FIELDS + 3]).is_equal(10)
	assert_bool(found).is_true()


func test_hull_integrity_raises_max_hp_and_hp() -> void:
	var w: SimWorld = _world()
	var i: int = _row(w, "hull_integrity")
	w.cinder.hp = 60.0
	assert_int(w.command_buy(i, 1)).is_equal(1)
	assert_float(w.cinder.max_hp).is_equal_approx(110.0, 1.0e-9)
	assert_float(w.cinder.hp).is_equal_approx(70.0, 1.0e-9)


func test_invalid_commands_leave_state_unchanged() -> void:
	var w: SimWorld = _world()
	var before: String = w.state_hash()
	assert_int(w.command_buy(-1, 1)).is_equal(0)
	assert_int(w.command_buy(w.config.upgrades.size(), 1)).is_equal(0)
	assert_int(w.command_buy(0, 0)).is_equal(0)
	assert_int(w.command_buy(0, 7)).is_equal(0)
	assert_str(w.state_hash()).is_equal(before)


func test_preview_does_not_mutate_and_matches_buy() -> void:
	var w: SimWorld = _world()
	var i: int = _row(w, "laser_output")
	var before: String = w.state_hash()
	var p: UpgradePreview = UpgradeSystem.preview(w, i, 1)
	assert_str(w.state_hash()).is_equal(before)
	assert_int(p.levels).is_equal(1)
	assert_bool(p.affordable).is_true()
	assert_float(p.cost.to_float()).is_equal_approx(10.0, 1.0e-6)
	assert_float(p.current_value).is_equal_approx(10.0, 1.0e-9)
	assert_float(p.next_value).is_equal_approx(11.0, 1.0e-9)
	assert_int(p.levels_to_milestone).is_equal(25)
	w.economy.scrap = BigNum.from_int(5)
	var q: UpgradePreview = UpgradeSystem.preview(w, i, 10)
	assert_int(q.levels).is_equal(0)
	assert_float(q.cost.to_float()).is_equal_approx(10.0, 1.0e-6)  # price of one level when nothing is affordable
	assert_bool(q.affordable).is_false()


func test_state_hash_includes_levels() -> void:
	var a: SimWorld = _world()
	var b: SimWorld = _world()
	b.run_levels[0] = 1
	assert_str(a.state_hash()).is_not_equal(b.state_hash())


func test_no_purchase_stats_equal_base() -> void:
	var w: SimWorld = _world()
	var base: StatBlock = StatBlock.from_base(w.config)
	assert_float(w.stats.laser_output).is_equal(base.laser_output)
	assert_float(w.stats.cycle_rate).is_equal(base.cycle_rate)
	assert_float(w.stats.hull_integrity).is_equal(base.hull_integrity)
	assert_float(w.stats.scrap_yield).is_equal(base.scrap_yield)
