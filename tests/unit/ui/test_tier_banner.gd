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


func test_banner_sits_directly_under_the_hud_bar() -> void:
	# M4-27 F8: the plate top is a small gap under the field top, not 17% of the field down.
	var b: TierBanner = _banner()
	b.set_field_rect(Rect2(0.0, 380.0, 1080.0, 1400.0))
	assert_float(b.position.y).is_equal(380.0 + TierBanner.TOP_GAP)


func test_banner_drops_below_a_wave_banner_that_is_up() -> void:
	# M4-27 F8: wave or boss banner and tier-up banner never overlap.
	var b: TierBanner = _banner()
	b.set_field_rect(Rect2(0.0, 380.0, 1080.0, 1400.0))
	var wave_bottom: Array[float] = [0.0]
	b.avoid_bottom = func() -> float: return wave_bottom[0]
	wave_bottom[0] = 512.0
	b.play_moment(_moment(2, true))
	assert_float(b.position.y).is_equal(512.0 + TierBanner.WAVE_GAP)
	assert_float(TierBanner.top_y(Rect2(0.0, 380.0, 1080.0, 1400.0), 0.0)).is_equal(404.0)


func test_a_wave_banner_that_starts_later_pushes_the_playing_banner_down() -> void:
	var b: TierBanner = _banner()
	b.set_field_rect(Rect2(0.0, 380.0, 1080.0, 1400.0))
	var wave_bottom: Array[float] = [0.0]
	b.avoid_bottom = func() -> float: return wave_bottom[0]
	b.play_moment(_moment(2, true))
	assert_float(b.position.y).is_equal(404.0)
	wave_bottom[0] = 412.0
	b._process(0.016)
	assert_float(b.position.y).is_equal(412.0 + TierBanner.WAVE_GAP)
	wave_bottom[0] = 0.0
	b._process(0.016)
	assert_float(b.position.y).is_equal(412.0 + TierBanner.WAVE_GAP)  # never back up mid-banner


func test_wave_banner_reports_the_bottom_of_its_plate_only_while_up() -> void:
	var w: WaveBanner = auto_free(WaveBanner.new())
	add_child(w)
	assert_float(w.occupied_bottom()).is_equal(0.0)
	w.play("WAVE 2", false, "", true)
	assert_float(w.occupied_bottom()).is_equal(w.global_position.y + WaveBanner.PLATE_SIZE.y)
	w.stop()
	assert_float(w.occupied_bottom()).is_equal(0.0)
