class_name TestModeRules
extends GdUnitTestSuite
## ModeRules and ModeCard (M4-07): data-driven unlock, permanence, mode-specific banking.

var _defs: Array[WaveModeDef] = ModeRules.load_defs()


func _bank(p: PlayerProfile, wave: int, mode: String, ticks: int = 1800, data: int = 5) -> Array[String]:
	var s: RunSummary = RunSummary.make(p.begin_run(), wave, BigNum.from_int(data), ticks)
	s.mode = mode
	if not p.bank_run(s):
		return []
	return ModeRules.apply_unlocks(p, _defs)


func _purge_def() -> WaveModeDef:
	return ModeRules.find_def(_defs, "purge")


func test_defs_load_and_thresholds_come_from_data() -> void:
	assert_int(_defs.size()).is_equal(2)
	assert_str(_defs[0].id).is_equal("timed")
	assert_int(_purge_def().unlock_best_timed_wave).is_greater(0)
	assert_object(ModeRules.find_def(_defs, "nope")).is_null()


func test_unlockable_follows_the_def_value() -> void:
	var n: int = _purge_def().unlock_best_timed_wave
	assert_array(ModeRules.unlockable(_defs, n - 1)).is_equal(["timed"])
	assert_array(ModeRules.unlockable(_defs, n)).is_equal(["timed", "purge"])


func test_locked_card_text_is_built_from_key_and_data_value() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	var n: int = _purge_def().unlock_best_timed_wave
	assert_array(_bank(p, n - 1, "timed")).is_empty()
	var cards: Array[ModeCard] = ModeRules.cards(p, _defs)
	assert_int(cards.size()).is_equal(2)
	assert_bool(cards[0].unlocked).is_true()
	assert_str(cards[0].locked_text).is_empty()
	var c: ModeCard = cards[1]
	assert_bool(c.unlocked).is_false()
	assert_int(c.unlock_wave).is_equal(n)
	assert_str(c.locked_text).is_equal(Strings.fill1("mode.locked", "n", str(n)))
	assert_str(c.locked_text).is_equal("Reach wave %d in TIMED to unlock" % n)
	assert_str(c.progress_text).is_equal("Best TIMED wave: %d" % (n - 1))
	assert_str(c.name_key).is_equal("mode.purge")


func test_timed_death_at_threshold_unlocks_once() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	var n: int = _purge_def().unlock_best_timed_wave
	assert_array(_bank(p, n, "timed")).is_equal(["purge"])
	assert_array(ModeRules.apply_unlocks(p, _defs)).is_empty()
	assert_array(p.modes_unlocked).is_equal(["timed", "purge"])
	assert_bool(ModeRules.cards(p, _defs)[1].unlocked).is_true()


func test_unlock_is_permanent_when_the_threshold_rises() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	assert_array(_bank(p, _purge_def().unlock_best_timed_wave, "timed")).is_equal(["purge"])
	var raised: WaveModeDef = _purge_def().duplicate()
	raised.unlock_best_timed_wave = 30
	var defs: Array[WaveModeDef] = [_defs[0], raised]
	assert_array(ModeRules.apply_unlocks(p, defs)).is_empty()
	assert_bool(p.mode_unlocked("purge")).is_true()
	assert_bool(ModeRules.cards(p, defs)[1].unlocked).is_true()


func test_purge_death_sets_only_the_purge_record() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	var n: int = _purge_def().unlock_best_timed_wave
	assert_array(_bank(p, n, "timed")).is_equal(["purge"])
	assert_array(_bank(p, 35, "purge")).is_empty()
	assert_int(p.best_wave_s1()).is_equal(n)
	assert_int(p.best_wave_of_mode("timed", 1)).is_equal(n)
	assert_int(p.best_wave_of_mode("purge", 1)).is_equal(35)
	assert_bool(p.mode_unlocked("purge")).is_true()
	assert_array(_bank(p, 10, "purge")).is_empty()
	assert_int(p.best_wave_of_mode("purge", 1)).is_equal(35)  # a lower run never lowers it


func test_purge_run_never_unlocks_purge() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	assert_array(_bank(p, 99, "purge")).is_empty()
	assert_bool(p.mode_unlocked("purge")).is_false()
	assert_int(p.best_wave_s1()).is_equal(0)
	assert_int(p.best_wave_of_mode("purge", 1)).is_equal(99)


func test_unimplemented_modes_are_hidden_and_never_unlock() -> void:
	var hidden: WaveModeDef = _purge_def().duplicate()
	hidden.implemented = false
	var defs: Array[WaveModeDef] = [_defs[0], hidden]
	assert_array(ModeRules.unlockable(defs, 999)).is_equal(["timed"])
	assert_int(ModeRules.cards(PlayerProfile.fresh(0, "t"), defs).size()).is_equal(1)


func test_card_selected_follows_last_mode() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	assert_bool(ModeRules.cards(p, _defs)[0].selected).is_true()
	assert_bool(p.select_mode("purge")).is_false()
	@warning_ignore("return_value_discarded")
	p.unlock_mode("purge")
	assert_bool(p.select_mode("purge")).is_true()
	assert_bool(ModeRules.cards(p, _defs)[1].selected).is_true()
	assert_bool(ModeRules.cards(p, _defs)[0].selected).is_false()
