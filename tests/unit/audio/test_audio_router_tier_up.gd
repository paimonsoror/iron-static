class_name TestAudioRouterTierUp
extends GdUnitTestSuite
## VT-5: a purchase that reaches a new visual tier plays exactly one sting (sfx_tier_up for MK II and III, the
## milestone chime for MK IV); other purchases keep the x25 rule; resume/skip never replays owned tiers.

var _world: SimWorld
var _spy: SpyAudioDirector
var _router: AudioEventRouter


func before_test() -> void:
	_world = SimWorld.new(SimConfigLoader.load_default(1))
	_spy = auto_free(SpyAudioDirector.new())
	_router = AudioEventRouter.new(_spy)
	_router.bind(_world)


func _row(id: String) -> int:
	for i: int in _world.config.upgrades.size():
		if _world.config.upgrades[i].id == id:
			return i
	return -1


func _buy(row: int, level: int) -> void:
	_world.events.push(SimEventKind.UPGRADE_BOUGHT, row, level)


func _stings() -> int:
	return _spy.count("sfx_tier_up") + _spy.count("sfx_milestone_x15")


func test_mk2_and_mk3_play_the_new_sting() -> void:
	_buy(0, 4)
	_buy(0, 5)
	_buy(0, 12)
	_router.update()
	assert_array(_spy.sfx).contains_exactly(["sfx_tier_up", "sfx_tier_up"])


func test_mk4_reuses_the_milestone_sound_once() -> void:
	_buy(0, 24)
	_router.update()
	_spy.sfx.clear()
	_buy(0, 25)  # MK IV and a multiple of 25: one sting, not two
	_router.update()
	assert_array(_spy.sfx).contains_exactly(["sfx_milestone_x15"])


func test_multi_buy_across_tiers_plays_one_sting() -> void:
	_buy(0, 26)  # 0 -> 26 crosses MK II, III and IV; not a multiple of 25
	_router.update()
	assert_array(_spy.sfx).contains_exactly(["sfx_milestone_x15"])
	_spy.sfx.clear()
	_buy(_row("hull_integrity"), 13)  # hull MK III via a multi-buy
	_router.update()
	assert_array(_spy.sfx).contains_exactly(["sfx_tier_up"])


func test_plain_rows_and_non_tier_levels_keep_the_old_rule() -> void:
	_buy(0, 6)  # inside MK II: silent after the first tier-up below
	_router.update()
	_spy.sfx.clear()
	_buy(0, 7)
	_buy(_row("cycle_rate"), 50)  # no tiers: x25 chime
	_router.update()
	assert_int(_spy.count("sfx_tier_up")).is_equal(0)
	assert_int(_spy.count("sfx_milestone_x15")).is_equal(1)


func test_levels_owned_at_bind_do_not_replay() -> void:
	_world.run_levels[0] = 12
	_router.bind(_world)
	_buy(0, 13)  # same tier as owned: nothing
	_router.update()
	assert_int(_stings()).is_equal(0)


func test_skip_adopts_levels_silently() -> void:
	_world.run_levels[0] = 30  # a fast-forward moved the level; its events are skipped
	_buy(0, 30)
	_router.skip()
	_buy(0, 31)
	_router.update()
	assert_int(_stings()).is_equal(0)


func test_slot_is_registered_and_quieter_than_the_milestone() -> void:
	assert_bool(AudioSlots.has("sfx_tier_up")).is_true()
	var tier: AudioSlot = AudioSlots.slot("sfx_tier_up")
	var milestone: AudioSlot = AudioSlots.slot("sfx_milestone_x15")
	assert_bool(tier.valid).is_true()
	assert_float(tier.volume_db).is_less(milestone.volume_db)
