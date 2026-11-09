class_name TestSettingsModel
extends GdUnitTestSuite
## SettingsModel (M3-18): order, option lists, string keys and example texts.


func test_order_and_label_keys_exist() -> void:
	assert_array(SettingsModel.ORDER).is_equal(
		[
			"sfx",
			"music",
			"muted",
			"reduce_motion",
			"shake",
			"scanlines",
			"number_format",
			"fps_cap",
			"haptics",
			"colorblind",
			"high_contrast"
		]
	)
	for setting: String in SettingsModel.ORDER:
		assert_bool(Strings.has_key(SettingsModel.label_key(setting))).is_true()


func test_option_lists() -> void:
	assert_array(SettingsModel.options("shake")).is_equal(["off", "low", "normal"])
	assert_array(SettingsModel.options("scanlines")).is_equal(["off", "low", "normal"])
	assert_array(SettingsModel.options("number_format")).is_equal(["short", "scientific", "engineering"])
	assert_array(SettingsModel.options("fps_cap")).is_equal(["30", "60"])
	assert_array(SettingsModel.options("colorblind")).is_equal(["off", "deuteranopia", "protanopia", "tritanopia"])
	assert_array(SettingsModel.options("sfx")).is_empty()


func test_every_option_key_is_a_string_key() -> void:
	for setting: String in ["shake", "scanlines", "number_format", "fps_cap", "colorblind"]:
		for k: String in SettingsModel.option_keys(setting):
			assert_bool(Strings.has_key(k)).is_true()
	assert_str(SettingsModel.option_key("fps_cap", "30")).is_equal("settings.opt.fps30")
	assert_str(SettingsModel.option_key("shake", "low")).is_equal("settings.opt.low")


func test_index_of_falls_back_to_first() -> void:
	assert_int(SettingsModel.index_of("shake", "normal")).is_equal(2)
	assert_int(SettingsModel.index_of("shake", "bogus")).is_equal(0)
	assert_int(SettingsModel.index_of("fps_cap", "60")).is_equal(1)


func test_example_texts() -> void:
	assert_str(SettingsModel.number_example(NumberFormat.SHORT)).is_equal("12.3M")
	assert_str(SettingsModel.number_example(NumberFormat.SCIENTIFIC)).is_equal("1.23e7")
	assert_str(SettingsModel.number_example(NumberFormat.ENGINEERING)).is_equal("12.3e6")


func test_volume_text_and_snap() -> void:
	assert_str(SettingsModel.volume_text(0.7)).is_equal("70%")
	assert_str(SettingsModel.volume_text(1.4)).is_equal("100%")
	assert_float(SettingsModel.snap_volume(0.52)).is_equal_approx(0.5, 0.0001)
	assert_float(SettingsModel.snap_volume(-1.0)).is_equal(0.0)


func test_reduce_motion_dims_shake_and_scanlines_only() -> void:
	assert_bool(SettingsModel.dimmed_by_reduce_motion("shake")).is_true()
	assert_bool(SettingsModel.dimmed_by_reduce_motion("scanlines")).is_true()
	assert_bool(SettingsModel.dimmed_by_reduce_motion("fps_cap")).is_false()
