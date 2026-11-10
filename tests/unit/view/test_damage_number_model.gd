class_name TestDamageNumberModel
extends GdUnitTestSuite
## DamageNumberModel (M4-20): show rules, merge, window budget, live cap, text, lifetime.

const MAX_HP: float = 1000.0


func _model() -> DamageNumberModel:
	var m := DamageNumberModel.new()
	m.advance(10.0)
	return m


func _live_slots(m: DamageNumberModel) -> Array[int]:
	var out: Array[int] = []
	for s: int in DamageNumberModel.POOL:
		if m.is_live(s):
			out.append(s)
	return out


func test_small_hits_show_nothing() -> void:
	var m: DamageNumberModel = _model()
	for i: int in 10:
		m.advance(10.0 + float(i) * 0.3)
		assert_bool(m.hit(i, 0.0, 0.0, 5.0, MAX_HP, false)).is_false()
	assert_int(m.live_count()).is_equal(0)


func test_one_percent_hit_shows_and_crit_always_shows() -> void:
	var m: DamageNumberModel = _model()
	assert_bool(m.hit(1, 0.0, 0.0, 10.0, MAX_HP, false)).is_true()
	assert_bool(m.hit(2, 0.0, 0.0, 1.0, MAX_HP, true)).is_true()
	assert_int(m.live_count()).is_equal(2)
	var kinds: Array[int] = []
	for s: int in _live_slots(m):
		kinds.append(m.kind_at(s))
	kinds.sort()
	assert_array(kinds).is_equal([DamageNumberModel.Kind.NORMAL, DamageNumberModel.Kind.CRIT])


func test_same_target_within_window_is_summed() -> void:
	var m: DamageNumberModel = _model()
	m.hit(7, 0.0, 0.0, 20.0, MAX_HP, false)
	m.advance(10.1)
	m.hit(7, 0.0, 0.0, 30.0, MAX_HP, false)
	m.advance(10.2)
	m.hit(7, 0.0, 0.0, 5.0, MAX_HP, false)  # below 1% but joins the live number
	assert_int(m.live_count()).is_equal(1)
	for s: int in _live_slots(m):
		assert_float(m.amount_at(s)).is_equal(55.0)
		assert_str(m.text_at(s)).is_equal("55")


func test_later_hit_starts_a_new_number() -> void:
	var m: DamageNumberModel = _model()
	m.hit(7, 0.0, 0.0, 20.0, MAX_HP, false)
	m.advance(10.3)
	m.hit(7, 0.0, 0.0, 20.0, MAX_HP, false)
	assert_int(m.live_count()).is_equal(2)


func test_thirty_hits_in_one_frame_cap_at_six_per_window() -> void:
	var m: DamageNumberModel = _model()
	for i: int in 30:
		m.hit(i, 0.0, 0.0, 20.0 + float(i), MAX_HP, false)
	assert_int(m.live_count()).is_equal(6)
	# the six best amounts survive (replacement keeps the top ones)
	var lowest: float = 1.0e9
	for s: int in _live_slots(m):
		lowest = minf(lowest, m.amount_at(s))
	assert_float(lowest).is_equal(44.0)
	# a new window opens after 0.5 s
	m.advance(10.55)
	for i: int in 30:
		m.hit(100 + i, 0.0, 0.0, 20.0, MAX_HP, false)
	assert_int(m.live_count()).is_equal(12)


func test_never_more_than_live_cap() -> void:
	var m: DamageNumberModel = _model()
	var t: float = 10.0
	for i: int in 400:
		t += 0.02
		m.advance(t)
		m.hit(i, 0.0, 0.0, 50.0, MAX_HP, i % 2 == 0)
		m.cinder_hit(10.0)
		assert_int(m.live_count()).is_less_equal(DamageNumberModel.POOL)
	m.live_cap = 12
	m.advance(t)
	assert_int(m.live_count()).is_less_equal(12)


func test_crit_outranks_normal_when_window_is_full() -> void:
	var m: DamageNumberModel = _model()
	for i: int in 6:
		m.hit(i, 0.0, 0.0, 500.0, MAX_HP, false)
	assert_bool(m.hit(50, 0.0, 0.0, 20.0, MAX_HP, false)).is_false()
	assert_bool(m.hit(51, 0.0, 0.0, 1.0, MAX_HP, true)).is_true()
	assert_int(m.live_count()).is_equal(6)


func test_text_styles_use_number_format() -> void:
	assert_str(DamageNumberModel.format_text(DamageNumberModel.Kind.NORMAL, 1500.0)).is_equal("1.5K")
	assert_str(DamageNumberModel.format_text(DamageNumberModel.Kind.CRIT, 12.0)).is_equal("[12]")
	assert_str(DamageNumberModel.format_text(DamageNumberModel.Kind.HEAL, 2500000.0)).is_equal("+2.5M")
	var m: DamageNumberModel = _model()
	m.heal(40.0)
	for s: int in _live_slots(m):
		assert_str(m.text_at(s)).starts_with("+")
		assert_int(m.kind_at(s)).is_equal(DamageNumberModel.Kind.HEAL)


func test_styles_match_the_gdd() -> void:
	assert_int(DamageNumberModel.size_of(DamageNumberModel.Kind.NORMAL)).is_equal(36)
	assert_int(DamageNumberModel.size_of(DamageNumberModel.Kind.CRIT)).is_equal(44)
	assert_int(DamageNumberModel.size_of(DamageNumberModel.Kind.OVERCRIT)).is_equal(56)
	assert_int(DamageNumberModel.size_of(DamageNumberModel.Kind.CINDER)).is_equal(36)
	assert_str(DamageNumberModel.color_of(DamageNumberModel.Kind.NORMAL).to_html(false)).is_equal("f2e6c9")
	assert_str(DamageNumberModel.color_of(DamageNumberModel.Kind.CRIT).to_html(false)).is_equal("ffd27a")
	assert_str(DamageNumberModel.color_of(DamageNumberModel.Kind.OVERCRIT).to_html(false)).is_equal("ffffff")
	assert_str(DamageNumberModel.color_of(DamageNumberModel.Kind.CINDER).to_html(false)).is_equal("ff3b30")
	assert_str(DamageNumberModel.color_of(DamageNumberModel.Kind.HEAL).to_html(false)).is_equal("2ee6d6")


func test_lifetime_expires_and_age_grows() -> void:
	var m: DamageNumberModel = _model()
	m.cinder_hit(30.0)
	m.advance(10.3)
	assert_int(m.live_count()).is_equal(1)
	for s: int in _live_slots(m):
		assert_float(m.age_at(s)).is_equal_approx(0.3, 0.0001)
	m.advance(10.61)
	assert_int(m.live_count()).is_equal(0)


func test_tier_cap() -> void:
	assert_int(DamageNumberModel.cap_for_tier(VisualQuality.Tier.HIGH)).is_equal(24)
	assert_int(DamageNumberModel.cap_for_tier(VisualQuality.Tier.MID)).is_equal(24)
	assert_int(DamageNumberModel.cap_for_tier(VisualQuality.Tier.LOW)).is_equal(12)
