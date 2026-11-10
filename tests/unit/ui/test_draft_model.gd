class_name TestDraftModel
extends GdUnitTestSuite
## DraftModel and DraftOpenFx (M4-16, R1-04): card texts and the concrete change numbers, the gamble card with both
## sides, picks line, first-draft note, the reroll state.

const STANDARD: Array[String] = ["patch_overcharge", "patch_plating", "patch_rate"]


func test_standard_cards_and_title() -> void:
	var c: RunController = DraftTestWorld.controller_with_draft(STANDARD)
	var m: DraftModel = DraftModel.from_world(c.world)
	assert_str(m.title()).is_equal("WAVE 5 CLEARED")
	assert_int(m.cards.size()).is_equal(3)
	assert_str(m.cards[0].title).is_equal("OVERCHARGE")
	assert_str(m.cards[0].benefit).is_equal("LASER OUTPUT +9% PER PICK")
	assert_bool(m.cards[0].gamble).is_false()
	assert_str(m.cards[0].cost_line).is_equal("")
	assert_int(m.cards[2].slot).is_equal(2)


func test_gamble_card_shows_both_sides() -> void:
	var c: RunController = DraftTestWorld.controller_with_draft(["patch_t_greed", "patch_t_glass", "patch_t_hardhide"])
	var m: DraftModel = DraftModel.from_world(c.world)
	assert_bool(m.cards[0].gamble).is_true()
	assert_str(m.cards[0].benefit).is_equal("DATA YIELD x1.5")
	var s: StatBlock = c.world.stats
	var hull: String = UpgradeRowModel.format_value("hull_integrity", s.hull_integrity)
	var laser: String = UpgradeRowModel.format_value("laser_output", s.laser_output)
	var half: String = UpgradeRowModel.format_value("hull_integrity", s.hull_integrity * 0.5)
	var seven: String = UpgradeRowModel.format_value("hull_integrity", s.hull_integrity * 0.7)
	var six: String = UpgradeRowModel.format_value("laser_output", s.laser_output * 0.6)
	assert_str(m.cards[0].cost_line).is_equal("COST: HULL INTEGRITY %s > %s" % [hull, half])
	assert_str(m.cards[1].cost_line).is_equal("COST: HULL INTEGRITY %s > %s" % [hull, seven])
	assert_str(m.cards[2].cost_line).is_equal("COST: LASER OUTPUT %s > %s" % [laser, six])


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
	assert_str(m.note()).is_equal("Patches last this deployment. One reroll per draft.")
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


func test_card_change_numbers_are_the_stats_before_and_after_one_pick() -> void:
	var c: RunController = DraftTestWorld.controller_with_draft(
		["patch_overcharge", "patch_plating", "patch_extraction"]
	)
	var m: DraftModel = DraftModel.from_world(c.world)
	var s: StatBlock = c.world.stats
	var laser_a: String = UpgradeRowModel.format_value("laser_output", s.laser_output)
	var laser_b: String = UpgradeRowModel.format_value("laser_output", s.laser_output * 1.09)
	assert_array(m.cards[0].change_lines).contains_exactly(["LASER OUTPUT %s > %s" % [laser_a, laser_b]])
	var hull_a: String = UpgradeRowModel.format_value("hull_integrity", s.hull_integrity)
	var hull_b: String = UpgradeRowModel.format_value("hull_integrity", s.hull_integrity * 1.12)
	assert_array(m.cards[1].change_lines).contains_exactly(["HULL INTEGRITY %s > %s" % [hull_a, hull_b]])
	assert_int(m.cards[2].change_lines.size()).is_equal(2)  # EXTRACTION changes scrap and data yield
	assert_str(m.cards[2].change_lines[1]).is_equal(
		"DATA YIELD %s > %s" % [NumberFormat.format_mult(1.0), NumberFormat.format_mult(1.09)]
	)
	assert_float(c.world.stats.laser_output).is_equal(s.laser_output)  # reading the card changed nothing


func test_a_second_pick_builds_on_the_picks_held() -> void:
	var picks: Dictionary[String, int] = {"patch_overcharge": 2}
	var c: RunController = DraftTestWorld.controller_with_draft(
		["patch_overcharge", "patch_plating", "patch_extraction"], picks
	)
	var m: DraftModel = DraftModel.from_world(c.world)
	var s: StatBlock = c.world.stats
	# DraftTestWorld adds the picks without re-resolving `world.stats`, so `s` is the unpatched base.
	var base: float = s.laser_output
	var now: String = UpgradeRowModel.format_value("laser_output", base * 1.18)
	var want: String = UpgradeRowModel.format_value("laser_output", base * 1.27)
	assert_str(m.cards[0].change_lines[0]).is_equal("LASER OUTPUT %s > %s" % [now, want])


func test_gamble_cost_is_a_concrete_change_and_the_family_and_icon_are_set() -> void:
	var c: RunController = DraftTestWorld.controller_with_draft(["patch_t_glass", "patch_t_hardhide", "patch_t_greed"])
	var m: DraftModel = DraftModel.from_world(c.world)
	var s: StatBlock = c.world.stats
	var hull_a: String = UpgradeRowModel.format_value("hull_integrity", s.hull_integrity)
	var hull_b: String = UpgradeRowModel.format_value("hull_integrity", s.hull_integrity * 0.7)
	assert_str(m.cards[0].cost_line).is_equal("COST: HULL INTEGRITY %s > %s" % [hull_a, hull_b])
	assert_str(m.cards[1].cost_line).starts_with("COST: LASER OUTPUT ")
	assert_str(m.cards[0].family).is_equal("arms")
	assert_str(m.cards[1].family).is_equal("chassis")
	assert_str(m.cards[2].family).is_equal("systems")
	assert_str(m.cards[0].icon_slot).is_equal("icon_laser_output")
	assert_str(m.cards[1].icon_slot).is_equal("icon_hull_integrity")  # ENEMY DAMAGE has no icon of its own
	assert_str(m.cards[2].icon_slot).is_equal("icon_cur_data")
	for card: DraftCardData in m.cards:
		assert_bool(ArtSlots.has(card.icon_slot)).is_true()


func test_family_colors_follow_the_palette() -> void:
	assert_object(DraftCardData.family_color("arms")).is_equal(Palette.AMBER)
	assert_object(DraftCardData.family_color("chassis")).is_equal(Palette.TEAL)
	assert_object(DraftCardData.family_color("systems")).is_equal(Palette.SCRAP)


func test_reroll_state_follows_the_draft() -> void:
	var c: RunController = DraftTestWorld.controller_with_draft(STANDARD)
	var m: DraftModel = DraftModel.from_world(c.world)
	assert_bool(m.can_reroll()).is_true()
	assert_str(m.reroll_text()).is_equal("REROLL ALL")
	c.world.draft.rerolls_used = 1
	m = DraftModel.from_world(c.world)
	assert_bool(m.can_reroll()).is_false()
	assert_str(m.reroll_text()).is_equal("REROLLED")
