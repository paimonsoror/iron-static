class_name TestFrameRules
extends GdUnitTestSuite
## FrameRules and FrameCard (M3-23): unlocks at banking, selection, comparison cards.

var _defs: Array[FrameDef] = FrameRules.load_defs()


func _service() -> FoundryService:
	return FoundryService.new(SimConfigLoader.load_foundry_defs(), SimConfigLoader.load_default(1).upgrades)


func _card(cards: Array[FrameCard], id: String) -> FrameCard:
	for c: FrameCard in cards:
		if c.id == id:
			return c
	return null


func _bank(p: PlayerProfile, wave: int) -> Array[String]:
	var id: int = p.begin_run()
	return FrameRules.bank(p, RunSummary.make(id, wave, BigNum.from_int(5)), _defs)


func test_fresh_profile() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	assert_array(p.frames_unlocked).is_equal(["vanguard"])
	assert_str(p.frame_selected).is_equal("vanguard")
	assert_bool(FrameRules.is_unlocked(p, "bulwark")).is_false()


func test_unlockable_thresholds_and_hidden_m6() -> void:
	assert_array(FrameRules.unlockable(_defs, 0)).is_equal(["vanguard"])
	assert_array(FrameRules.unlockable(_defs, 7)).is_equal(["vanguard"])
	assert_array(FrameRules.unlockable(_defs, 8)).is_equal(["vanguard", "bulwark"])
	assert_array(FrameRules.unlockable(_defs, 999)).is_equal(["vanguard", "bulwark", "striker"])


func test_banking_unlocks_once() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	assert_array(_bank(p, 7)).is_empty()
	assert_array(_bank(p, 8)).is_equal(["bulwark"])
	assert_array(_bank(p, 8)).is_empty()
	assert_array(p.frames_unlocked).is_equal(["vanguard", "bulwark"])
	assert_array(_bank(p, 15)).is_equal(["striker"])
	assert_array(_bank(p, 200)).is_empty()
	assert_bool(p.is_frame_unlocked("salvager")).is_false()
	assert_bool(p.is_frame_unlocked("longshot")).is_false()


func test_rejected_bank_unlocks_nothing() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	var s: RunSummary = RunSummary.make(p.begin_run(), 20, BigNum.zero())
	s.counts_for_progress = false
	assert_array(FrameRules.bank(p, s, _defs)).is_empty()
	assert_array(p.frames_unlocked).is_equal(["vanguard"])
	assert_array(FrameRules.apply_unlocks(p, _defs)).is_empty()


func test_select_requires_unlock_and_roundtrips() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	assert_bool(FrameRules.select(p, "striker")).is_false()
	assert_str(p.frame_selected).is_equal("vanguard")
	assert_bool(FrameRules.select(p, "nope")).is_false()
	assert_array(_bank(p, 15)).is_equal(["bulwark", "striker"])
	assert_bool(FrameRules.select(p, "striker")).is_true()
	var back: PlayerProfile = PlayerProfile.from_dict(p.to_dict())
	assert_str(back.frame_selected).is_equal("striker")
	assert_array(back.load_errors).is_empty()


func test_invalid_saved_selection_falls_back() -> void:
	var d: Dictionary = PlayerProfile.fresh(0, "t").to_dict()
	d["frame_selected"] = "striker"
	var p: PlayerProfile = PlayerProfile.from_dict(d)
	assert_str(p.frame_selected).is_equal("vanguard")
	assert_int(p.load_errors.size()).is_greater(0)
	assert_str(FrameRules.selected_id(p, _defs)).is_equal("vanguard")


func test_cards_list_and_state() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	p.best_wave["1"] = 5
	var cards: Array[FrameCard] = FrameRules.cards(p, _defs, _service())
	assert_int(cards.size()).is_equal(3)
	assert_bool(_card(cards, "salvager") == null).is_true()
	var v: FrameCard = _card(cards, "vanguard")
	assert_bool(v.selected).is_true()
	assert_bool(v.locked).is_false()
	assert_str(v.condition_key).is_empty()
	var b: FrameCard = _card(cards, "bulwark")
	assert_bool(b.locked).is_true()
	assert_bool(b.selected).is_false()
	assert_str(b.condition_key).is_equal("frame.locked_wave")
	assert_int(b.unlock_best_wave).is_equal(8)
	assert_int(b.best_wave).is_equal(5)
	assert_str(b.passive_desc_key).is_equal("frame.passive_desc.bulwark")


func test_bulwark_deltas_vs_vanguard() -> void:
	var cards: Array[FrameCard] = FrameRules.cards(PlayerProfile.fresh(0, "t"), _defs, _service())
	var b: FrameCard = _card(cards, "bulwark")
	assert_float(b.delta("hull")).is_equal_approx(60.0, 1e-6)
	assert_float(b.delta("rate")).is_equal_approx(-25.0, 1e-6)
	assert_float(b.delta("range")).is_equal_approx(-8.0, 1e-6)
	assert_float(b.delta("repair")).is_equal_approx(30.0, 1e-6)
	assert_float(b.delta("damage")).is_equal_approx(0.0, 1e-6)
	var v: FrameCard = _card(cards, "vanguard")
	for key: String in FrameCard.STAT_KEYS:
		assert_float(v.delta(key)).is_equal_approx(0.0, 1e-9)
	assert_float(v.power_rating_delta).is_equal_approx(0.0, 1e-9)


func test_striker_deltas() -> void:
	var s: FrameCard = _card(FrameRules.cards(PlayerProfile.fresh(0, "t"), _defs, _service()), "striker")
	assert_float(s.delta("rate")).is_equal_approx(40.0, 1e-6)
	assert_float(s.delta("damage")).is_equal_approx(-10.0, 1e-6)
	assert_float(s.delta("hull")).is_equal_approx(-35.0, 1e-6)
	assert_float(s.delta("crit")).is_equal_approx(150.0, 1e-6)


func test_reference_follows_selection() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	assert_array(_bank(p, 8)).is_equal(["bulwark"])
	assert_bool(FrameRules.select(p, "bulwark")).is_true()
	var cards: Array[FrameCard] = FrameRules.cards(p, _defs, _service())
	assert_float(_card(cards, "bulwark").delta("hull")).is_equal_approx(0.0, 1e-9)
	assert_float(_card(cards, "vanguard").delta("hull")).is_equal_approx(-37.5, 1e-6)
	var fixed: Array[FrameCard] = FrameRules.cards(p, _defs, _service(), "vanguard")
	assert_float(_card(fixed, "bulwark").delta("hull")).is_equal_approx(60.0, 1e-6)


func test_power_rating_includes_foundry() -> void:
	var svc: FoundryService = _service()
	var plain: PlayerProfile = PlayerProfile.fresh(0, "t")
	var rich: PlayerProfile = PlayerProfile.fresh(0, "t")
	rich.set_foundry_level("laser_output", 20)
	rich.set_foundry_level("hull_integrity", 20)
	var a: FrameCard = _card(FrameRules.cards(plain, _defs, svc), "bulwark")
	var b: FrameCard = _card(FrameRules.cards(rich, _defs, svc), "bulwark")
	assert_float(a.power_rating).is_greater(20.0)
	assert_float(b.power_rating).is_greater(a.power_rating)
	assert_float(a.delta("hull")).is_equal_approx(b.delta("hull"), 1e-9)
