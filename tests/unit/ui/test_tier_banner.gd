class_name TestTierBanner
extends GdUnitTestSuite
## VT-5: the tier-up banner (text, start state with and without motion) and the 3 s teal next-look line of a row.


func _banner() -> TierBanner:
	var b: TierBanner = auto_free(TierBanner.new())
	add_child(b)
	return b


func _moment(tier: int, flat: bool) -> TierUpMoment:
	var m: TierUpMoment = TierUpMoment.new()
	m.stat = "laser_output"
	m.tier = tier
	m.banner_key = "vt.banner.laser"
	m.flat = flat
	return m


func _plate(b: TierBanner) -> Control:
	return b.get_child(0) as Control


func test_text_and_hidden_when_idle() -> void:
	var b: TierBanner = _banner()
	assert_bool(b.is_playing()).is_false()
	b.play_moment(_moment(2, false))
	assert_bool(b.is_playing()).is_true()
	assert_str(b.title_text()).is_equal("LASER MK II")
	assert_str(b.sub_text()).is_equal("BEAM OUTPUT TIER UP")


func test_slide_starts_above_and_transparent() -> void:
	var b: TierBanner = _banner()
	b.play_moment(_moment(3, false))
	assert_float(_plate(b).position.y).is_less(0.0)
	assert_float(_plate(b).modulate.a).is_equal(0.0)


func test_reduce_motion_has_no_slide_and_is_visible_at_once() -> void:
	var b: TierBanner = _banner()
	b.play_moment(_moment(3, true))
	assert_float(_plate(b).position.y).is_equal(0.0)
	assert_float(_plate(b).modulate.a).is_equal(1.0)
	assert_bool(b.is_playing()).is_true()


func test_cancel_hides() -> void:
	var b: TierBanner = _banner()
	b.play_moment(_moment(4, false))
	b.cancel()
	assert_bool(b.is_playing()).is_false()


func test_banner_sits_below_the_hud_bar_in_the_field() -> void:
	var b: TierBanner = _banner()
	b.set_field_rect(Rect2(0.0, 300.0, 1080.0, 900.0))
	assert_float(b.position.y).is_greater(300.0)
	assert_float(b.position.y + b.size.y).is_less(1200.0)
	assert_float(b.position.x + b.size.x * 0.5).is_equal_approx(540.0, 0.5)
