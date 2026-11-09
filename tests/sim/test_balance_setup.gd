class_name TestBalanceSetup
extends GdUnitTestSuite
## BalanceSetup (M3-08, M3-24): Foundry specs, frame validation and the checked-in Foundry profiles.

const PROFILES: PackedStringArray = ["res://tests/profiles/foundry_300.json", "res://tests/profiles/foundry_1k.json"]


func test_foundry_spec_parses_pairs() -> void:
	var spec: BalanceSetup.FoundrySpec = BalanceSetup.parse_foundry_spec("laser_output=5,hull_integrity=4")
	assert_str(spec.error).is_empty()
	assert_int(spec.levels["laser_output"]).is_equal(5)
	assert_int(spec.levels["hull_integrity"]).is_equal(4)
	assert_bool(BalanceSetup.parse_foundry_spec("").levels.is_empty()).is_true()


func test_foundry_spec_rejects_bad_input() -> void:
	assert_str(BalanceSetup.parse_foundry_spec("laser_output").error).is_not_empty()
	assert_str(BalanceSetup.parse_foundry_spec("laser_output=x").error).is_not_empty()
	assert_str(BalanceSetup.parse_foundry_spec("laser_output=-1").error).is_not_empty()


func test_unknown_ids_are_errors() -> void:
	assert_str(BalanceSetup.foundry_error({"laser_output": 1})).is_empty()
	assert_str(BalanceSetup.foundry_error({"bogus": 1})).contains("bogus")
	assert_str(BalanceSetup.frame_error("vanguard")).is_empty()
	assert_str(BalanceSetup.frame_error("bulwark")).is_empty()
	assert_str(BalanceSetup.frame_error("nope")).contains("unknown")
	assert_str(BalanceSetup.frame_error("salvager")).contains("not implemented")


func test_implemented_frames_start_with_vanguard() -> void:
	var ids: PackedStringArray = BalanceSetup.implemented_frames()
	assert_str(ids[0]).is_equal("vanguard")
	assert_bool(ids.has("bulwark") and ids.has("striker")).is_true()
	assert_bool(ids.has("salvager")).is_false()


func test_profiles_record_their_true_cost() -> void:
	for path: String in PROFILES:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		assert_bool(parsed is Dictionary).is_true()
		var dict: Dictionary = parsed
		var levels: Dictionary = dict["foundry_levels"]
		assert_str(BalanceSetup.foundry_error(levels)).is_empty()
		var total: float = dict["total_cost"]
		assert_float(BalanceSetup.foundry_cost(levels)).is_equal(total)


func test_profile_sizes_are_about_300_and_1000() -> void:
	var small: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILES[0]))
	var big: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROFILES[1]))
	var small_cost: float = small["total_cost"]
	var big_cost: float = big["total_cost"]
	assert_float(small_cost).is_between(280.0, 340.0)
	assert_float(big_cost).is_between(950.0, 1050.0)


func test_config_with_foundry_and_frame() -> void:
	var cfg: SimConfig = BalanceSetup.make_config(3, 1, 0, {"laser_output": 5}, "bulwark")
	assert_str(cfg.frame_id).is_equal("bulwark")
	assert_int(cfg.foundry_levels.size()).is_equal(cfg.upgrades.size())
	var plain: SimConfig = BalanceSetup.make_config(3, 1, 0, {}, "vanguard")
	assert_int(plain.foundry_levels.size()).is_equal(0)
	assert_str(plain.frame_id).is_equal("vanguard")


func test_config_modes() -> void:
	assert_str(BalanceSetup.make_config(3, 1, 0, {}, "vanguard").wave_mode).is_equal("timed")
	assert_str(BalanceSetup.make_config(3, 1, 0, {}, "vanguard", "timed").wave_mode).is_equal("timed")
	var purge: SimConfig = BalanceSetup.make_config(3, 1, 0, {"laser_output": 2}, "bulwark", "purge")
	assert_str(purge.wave_mode).is_equal("purge")
	assert_str(purge.frame_id).is_equal("bulwark")
