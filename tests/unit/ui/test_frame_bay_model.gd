class_name TestFrameBayModel
extends GdUnitTestSuite
## FrameBayModel (M3-29): delta, lock and PR texts from real FrameRules cards.

var _defs: Array[FrameDef] = FrameRules.load_defs()


func _cards(best: int) -> Array[FrameCard]:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	if best > 0:
		var id: int = p.begin_run()
		@warning_ignore("return_value_discarded")
		FrameRules.bank(p, RunSummary.make(id, best, BigNum.from_int(5)), _defs)
	var svc := FoundryService.new(SimConfigLoader.load_foundry_defs(), SimConfigLoader.load_default(1).upgrades)
	return FrameRules.cards(p, _defs, svc)


func _card(cards: Array[FrameCard], id: String) -> FrameCard:
	return cards[FrameBayModel.index_of(cards, id)]


func test_only_three_frames_listed() -> void:
	var ids: Array[String] = []
	for c: FrameCard in _cards(0):
		ids.append(c.id)
	assert_array(ids).is_equal(["vanguard", "bulwark", "striker"])


func test_bulwark_vs_vanguard_delta_texts() -> void:
	var b: FrameCard = _card(_cards(0), "bulwark")
	assert_str(FrameBayModel.row_text(b, "hull")).is_equal("HULL +60%")
	assert_str(FrameBayModel.delta_text(b.delta("rate"))).is_equal("-25%")
	assert_str(FrameBayModel.row_text(b, "rate")).is_equal("FIRE RATE -25%")


func test_delta_text_rounding_and_sign() -> void:
	assert_str(FrameBayModel.delta_text(0.4)).is_equal("0%")
	assert_str(FrameBayModel.delta_text(-0.4)).is_equal("0%")
	assert_str(FrameBayModel.delta_text(59.6)).is_equal("+60%")
	assert_int(FrameBayModel.sign_of(-0.4)).is_equal(0)
	assert_int(FrameBayModel.sign_of(-30.0)).is_equal(-1)
	assert_float(FrameBayModel.bar_fraction(250.0)).is_equal(1.0)
	assert_float(FrameBayModel.bar_fraction(-50.0)).is_equal(-0.5)


func test_lock_text_at_best_5() -> void:
	var b: FrameCard = _card(_cards(5), "bulwark")
	assert_str(FrameBayModel.lock_text(b)).is_equal("REACH WAVE 8")
	assert_str(FrameBayModel.progress_text(b)).is_equal("BEST W5")
	assert_float(FrameBayModel.progress_fraction(b)).is_equal_approx(0.625, 0.001)
	assert_int(FrameBayModel.action_of(b)).is_equal(FrameBayModel.Action.LOCKED)
	assert_str(FrameBayModel.action_text(b)).is_equal("REACH WAVE 8")


func test_unlocked_texts_and_actions() -> void:
	var cards: Array[FrameCard] = _cards(20)
	var b: FrameCard = _card(cards, "bulwark")
	assert_str(FrameBayModel.lock_text(b)).is_equal("")
	assert_str(FrameBayModel.progress_text(b)).is_equal("")
	assert_int(FrameBayModel.action_of(b)).is_equal(FrameBayModel.Action.SELECT)
	assert_str(FrameBayModel.action_text(b)).is_equal("SELECT")
	var v: FrameCard = _card(cards, "vanguard")
	assert_int(FrameBayModel.action_of(v)).is_equal(FrameBayModel.Action.CONFIRM)


func test_pr_texts() -> void:
	var cards: Array[FrameCard] = _cards(0)
	var v: FrameCard = _card(cards, "vanguard")
	assert_str(FrameBayModel.pr_text(v)).starts_with("PR ")
	assert_str(FrameBayModel.pr_delta_text(v)).is_equal("")
	var b: FrameCard = _card(cards, "bulwark")
	assert_str(FrameBayModel.pr_delta_text(b)).is_not_empty()


func test_wrap_index() -> void:
	assert_int(FrameBayModel.wrap_index(0, -1, 3)).is_equal(2)
	assert_int(FrameBayModel.wrap_index(2, 1, 3)).is_equal(0)
	assert_int(FrameBayModel.wrap_index(0, 1, 0)).is_equal(0)
