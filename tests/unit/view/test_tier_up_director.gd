class_name TestTierUpDirector
extends GdUnitTestSuite
## VT-5: TierUpDirector turns level changes into tier-up moments (single, multi-cross, resume skip, replacement
## inside the 2 s window, banner sequencing and timings) and the tracker/model rules behind it.

var _world: SimWorld
var _dir: TierUpDirector
var _laser: int
var _hull: int
var _nano: int
var _plating: int
var _cycle: int


func before_test() -> void:
	_world = SimWorld.new(SimConfigLoader.load_default(1))
	_laser = _row("laser_output")
	_hull = _row("hull_integrity")
	_nano = _row("nano_repair")
	_plating = _row("plating_pct")
	_cycle = _row("cycle_rate")
	_dir = TierUpDirector.new()
	_dir.bind(_world)


func _row(id: String) -> int:
	for i: int in _world.config.upgrades.size():
		if _world.config.upgrades[i].id == id:
			return i
	return -1


func _banner(now_s: float) -> TierUpMoment:
	_dir.update(_world, now_s, false)
	return _dir.take_banner()


func test_single_tier_up_gives_flash_and_banner() -> void:
	_world.run_levels[_laser] = 5
	_dir.update(_world, 1.0, false)
	var flash: TierUpMoment = _dir.take_flash()
	var banner: TierUpMoment = _dir.take_banner()
	assert_object(flash).is_not_null()
	assert_int(flash.tier).is_equal(2)
	assert_str(banner.title()).is_equal("LASER MK II")
	assert_str(banner.sub()).is_equal("BEAM OUTPUT TIER UP")
	assert_object(_dir.take_flash()).is_null()  # consumed
	assert_object(_dir.take_banner()).is_null()


func test_no_moment_without_a_new_tier() -> void:
	_world.run_levels[_laser] = 4
	_world.run_levels[_cycle] = 40  # a row without tiers
	_dir.update(_world, 1.0, false)
	assert_object(_dir.take_flash()).is_null()
	_world.run_levels[_laser] = 5
	_dir.update(_world, 2.0, false)
	assert_object(_dir.take_flash()).is_not_null()
	_world.run_levels[_laser] = 11  # still MK II
	_dir.update(_world, 3.0, false)
	assert_object(_dir.take_flash()).is_null()


func test_plating_first_mark_has_no_banner_second_has() -> void:
	_world.run_levels[_plating] = 3
	_dir.update(_world, 1.0, false)
	assert_object(_dir.take_flash()).is_null()
	_world.run_levels[_plating] = 8
	_dir.update(_world, 2.0, false)
	assert_str(_dir.take_banner().title()).is_equal("PLATING MK II")


func test_multi_buy_crossing_tiers_announces_the_final_one() -> void:
	_world.run_levels[_laser] = 13  # 0 -> 13 crosses MK II and MK III
	_dir.update(_world, 1.0, false)
	assert_int(_dir.take_flash().tier).is_equal(3)
	assert_str(_dir.take_banner().title()).is_equal("LASER MK III")
	assert_object(_dir.take_banner()).is_null()


func test_highest_tier_wins_when_two_rows_rise_in_one_frame() -> void:
	_world.run_levels[_hull] = 5
	_world.run_levels[_nano] = 12
	_dir.update(_world, 1.0, false)
	var m: TierUpMoment = _dir.take_banner()
	assert_int(m.tier).is_equal(3)
	assert_str(m.title()).is_equal("REPAIR MK III")


func test_resume_and_rebind_do_not_replay_owned_levels() -> void:
	_world.run_levels[_laser] = 30
	_world.run_levels[_hull] = 12
	var fresh: TierUpDirector = TierUpDirector.new()
	fresh.bind(_world)  # a resumed run: levels already owned
	fresh.update(_world, 1.0, false)
	assert_object(fresh.take_flash()).is_null()
	assert_object(fresh.take_banner()).is_null()
	_world.run_levels[_laser] = 31  # no tier change either
	fresh.update(_world, 2.0, false)
	assert_object(fresh.take_flash()).is_null()


func test_sync_skips_a_debug_fast_forward_and_drops_waiting() -> void:
	_world.run_levels[_laser] = 5
	_dir.update(_world, 1.0, false)  # banner started
	@warning_ignore("return_value_discarded")
	_dir.take_banner()
	_world.run_levels[_hull] = 5  # waiting behind it
	_dir.update(_world, 1.2, false)
	_world.run_levels[_laser] = 60
	_world.run_levels[_nano] = 40
	_dir.sync(_world)
	_dir.update(_world, 1.3, false)
	assert_object(_dir.take_banner()).is_null()
	assert_bool(_dir.is_busy(1.3)).is_false()  # sync drops the waiting moment and the busy window


func test_second_tier_up_waits_for_the_banner_then_plays() -> void:
	_world.run_levels[_laser] = 5
	assert_str(_banner(10.0).title()).is_equal("LASER MK II")
	_world.run_levels[_hull] = 5
	_dir.update(_world, 10.5, false)
	assert_object(_dir.take_flash()).is_not_null()  # the flash is immediate
	assert_object(_dir.take_banner()).is_null()  # the banner waits
	var total: float = TierUpDirector.banner_total_s(2, false)
	assert_object(_banner(10.0 + total - 0.05)).is_null()
	assert_str(_banner(10.0 + total + 0.01).title()).is_equal("HULL MK II")


func test_newer_tier_up_replaces_the_waiting_one() -> void:
	_world.run_levels[_laser] = 5
	_dir.update(_world, 10.0, false)
	@warning_ignore("return_value_discarded")
	_dir.take_banner()
	_world.run_levels[_hull] = 5
	_dir.update(_world, 10.4, false)
	_world.run_levels[_nano] = 12  # inside 2 s: replaces the waiting HULL MK II
	_dir.update(_world, 10.8, false)
	var m: TierUpMoment = _banner(10.0 + TierUpDirector.banner_total_s(2, false) + 0.01)
	assert_str(m.title()).is_equal("REPAIR MK III")
	assert_object(_banner(20.0)).is_null()  # the replaced one never shows


func test_stale_waiting_moment_is_dropped() -> void:
	_world.run_levels[_laser] = 5
	_dir.update(_world, 10.0, false)
	@warning_ignore("return_value_discarded")
	_dir.take_banner()
	_world.run_levels[_hull] = 5
	_dir.update(_world, 10.1, false)
	assert_object(_banner(12.5)).is_null()  # waited longer than COALESCE_S


func test_banner_timings_and_flat_mode() -> void:
	assert_float(TierUpDirector.banner_total_s(2, false)).is_equal_approx(0.15 + 1.0 + 0.3, 0.0001)
	assert_float(TierUpDirector.banner_total_s(3, false)).is_equal_approx(0.15 + 1.3 + 0.3, 0.0001)
	assert_float(TierUpDirector.banner_total_s(4, false)).is_equal_approx(1.75, 0.0001)
	assert_float(TierUpDirector.banner_total_s(3, true)).is_equal_approx(1.6, 0.0001)  # no slide
	_world.run_levels[_laser] = 12
	_dir.update(_world, 1.0, true)
	assert_bool(_dir.take_banner().flat).is_true()


func test_model_tier_up_rules() -> void:
	var m: VisualTierModel = VisualTierModel.shared()
	assert_int(m.tier_up("laser_output", 0, 4)).is_equal(0)
	assert_int(m.tier_up("laser_output", 4, 5)).is_equal(2)
	assert_int(m.tier_up("laser_output", 0, 100)).is_equal(4)
	assert_int(m.tier_up("laser_output", 30, 10)).is_equal(0)  # a drop (new run) is not a tier-up
	assert_int(m.tier_up("cycle_rate", 0, 50)).is_equal(0)
	assert_str(m.banner_key("hull_integrity", 4)).is_equal("vt.banner.hull")
	assert_str(m.banner_key("hull_integrity", 1)).is_empty()
