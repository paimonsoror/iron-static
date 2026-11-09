class_name TestDraftModel
extends GdUnitTestSuite
## DraftModel and DraftOpenFx (M4-16): card texts, the gamble card with both sides, picks line, first-draft note.

const STANDARD: Array[String] = ["patch_overcharge", "patch_plating", "patch_rate"]


func test_standard_cards_and_title() -> void:
	var c: RunController = DraftTestWorld.controller_with_draft(STANDARD)
	var m: DraftModel = DraftModel.from_world(c.world)
	assert_str(m.title()).is_equal("WAVE 10 CLEARED")
	assert_int(m.cards.size()).is_equal(3)
	assert_str(m.cards[0].title).is_equal("OVERCHARGE")
	assert_str(m.cards[0].benefit).is_equal("LASER OUTPUT +15% PER PICK")
	assert_bool(m.cards[0].gamble).is_false()
	assert_str(m.cards[0].cost_line).is_equal("")
	assert_int(m.cards[2].slot).is_equal(2)


func test_gamble_card_shows_both_sides() -> void:
	var c: RunController = DraftTestWorld.controller_with_draft(["patch_t_greed", "patch_t_glass", "patch_t_hardhide"])
	var m: DraftModel = DraftModel.from_world(c.world)
	assert_bool(m.cards[0].gamble).is_true()
	assert_str(m.cards[0].benefit).is_equal("DATA YIELD x1.8")
	assert_str(m.cards[0].cost_line).is_equal("COST: HULL INTEGRITY x0.5")
	assert_str(m.cards[1].cost_line).is_equal("COST: HULL INTEGRITY x0.7")
	assert_str(m.cards[2].cost_line).is_equal("COST: LASER OUTPUT x0.6")


func test_picks_line_lists_picks_with_max() -> void:
	var picks: Dictionary[String, int] = {"patch_overcharge": 2, "patch_plating": 1}
	var c: RunController = DraftTestWorld.controller_with_draft(STANDARD, picks)
	var m: DraftModel = DraftModel.from_world(c.world)
	assert_str(m.picks_line()).is_equal("PICKS: OVERCHARGE 2/5, PLATING 1/5")
	assert_str(m.cards[0].progress_text()).is_equal("OVERCHARGE 2/5")
	assert_bool(m.show_note).is_false()
	assert_str(m.note()).is_equal("")


func test_first_draft_shows_the_note_and_no_picks_line() -> void:
	var c: RunController = DraftTestWorld.controller_with_draft(STANDARD)
	var m: DraftModel = DraftModel.from_world(c.world)
	assert_str(m.note()).is_equal("PATCHES LAST THIS DEPLOYMENT")
	assert_str(m.picks_line()).is_equal("")


func test_every_patch_has_texts_and_every_gamble_a_cost() -> void:
	var c: RunController = DraftTestWorld.controller_with_draft(STANDARD)
	for i: int in c.world.config.patches.size():
		var def: PatchDef = c.world.config.patches[i]
		var data: DraftCardData = DraftCardData.from_def(def, i, 0, 0)
		assert_str(data.title).is_not_empty()
		assert_str(data.benefit).is_not_empty()
		assert_bool(data.cost_line.is_empty()).is_equal(not def.is_gamble())


func test_open_fx_numbers() -> void:
	assert_int(DraftOpenFx.ring_count(true)).is_equal(0)
	assert_int(DraftOpenFx.ring_count(false)).is_equal(DraftOpenFx.RINGS)
	assert_float(DraftOpenFx.card_fade(0.0, true)).is_equal(1.0)
	assert_float(DraftOpenFx.card_fade(0.0, false)).is_equal(0.0)
	assert_float(DraftOpenFx.card_fade(1.0, false)).is_equal(1.0)
	assert_float(DraftOpenFx.alpha(0.0)).is_equal(0.0)
	assert_float(DraftOpenFx.alpha(1.0)).is_equal(0.0)
	assert_float(DraftOpenFx.alpha(0.5)).is_greater(0.0)
	assert_float(DraftOpenFx.radius(1.0)).is_equal(DraftOpenFx.MAX_RADIUS)
	assert_float(DraftOpenFx.progress(1, DraftOpenFx.total_s())).is_equal(1.0)
	assert_float(DraftOpenFx.progress(1, 0.0)).is_equal(0.0)
