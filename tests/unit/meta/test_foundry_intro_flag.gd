class_name TestFoundryIntroFlag
extends GdUnitTestSuite
## FoundryIntroFlag (FO-1): lives in the profile extra dict, missing or damaged means "show the dialog".


func test_missing_key_means_shown() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	assert_bool(FoundryIntroFlag.is_hidden(p)).is_false()


func test_damaged_value_means_shown() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	p.extra[FoundryIntroFlag.KEY] = "yes"
	assert_bool(FoundryIntroFlag.is_hidden(p)).is_false()


func test_set_reports_change_and_round_trips() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	assert_bool(FoundryIntroFlag.set_hidden(p, false)).is_false()
	assert_bool(FoundryIntroFlag.set_hidden(p, true)).is_true()
	assert_bool(FoundryIntroFlag.set_hidden(p, true)).is_false()
	assert_bool(FoundryIntroFlag.is_hidden(PlayerProfile.from_dict(p.to_dict()))).is_true()


func test_independent_of_ftue_state() -> void:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	var s: FtueState = FtueState.load_from(FtueScript.load_default(), p)
	s.skip_all()
	s.store_to(p)
	assert_bool(FoundryIntroFlag.is_hidden(p)).is_false()
	assert_bool(FoundryIntroFlag.set_hidden(p, true)).is_true()
	assert_bool(FtueState.load_from(FtueScript.load_default(), p).skipped).is_true()
