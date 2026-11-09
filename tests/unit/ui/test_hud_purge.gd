class_name TestHudPurge
extends GdUnitTestSuite
## HUD in PURGE (M4-09): "{n} LEFT" from PurgeClock.remaining_quota in the timer slot, the bar is the backstop,
## TIMED stays on the clock; the HUD never mutates the sim.

const SCENE: PackedScene = preload("res://src/ui/hud.tscn")


func _hud() -> Hud:
	var root: Control = auto_free(Control.new())
	root.size = Vector2(1080.0, 2400.0)
	add_child(root)
	var h: Hud = SCENE.instantiate()
	root.add_child(h)
	return h


func _world(mode: String, ticks: int) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.debug_invulnerable = true
	@warning_ignore("return_value_discarded")
	SimConfigLoader.apply_mode(cfg, mode)
	var w := SimWorld.new(cfg)
	for i: int in ticks:
		w.step()
	return w


func test_purge_hud_shows_the_remaining_quota_and_the_backstop_bar() -> void:
	var h: Hud = _hud()
	var w: SimWorld = _world("purge", 100)
	var before: int = w.tick
	var left: int = PurgeClock.remaining_quota(w)
	assert_int(left).is_greater(0)
	h.refresh(w, 1.0)
	var label: Label = h.get_node("%TimerLabel")
	var bar: SegmentedBar = h.get_node("%TimerBar")
	assert_str(label.text).is_equal("%d LEFT" % left)
	assert_float(bar.max_value).is_equal(float(PurgeClock.backstop_ticks(w)))
	assert_int(w.tick).is_equal(before)  # read-only


func test_timed_hud_keeps_the_clock_and_the_wave_length_bar() -> void:
	var h: Hud = _hud()
	var w: SimWorld = _world("timed", 100)
	h.refresh(w, 1.0)
	var label: Label = h.get_node("%TimerLabel")
	var bar: SegmentedBar = h.get_node("%TimerBar")
	assert_str(label.text).is_equal("%ds" % ceili(float(Ticks.WAVE_TICKS - w.wave_tick) / float(Ticks.TICK_RATE)))
	assert_float(bar.max_value).is_equal(float(Ticks.WAVE_TICKS))
	assert_float(label.offset_right).is_equal(Hud.TIMED_LABEL_RIGHT)


func test_quota_text_counts_down_as_enemies_die() -> void:
	var m := HudModel.new()
	m.set_values(1, 10.0, 10.0, BigNum.zero(), BigNum.zero(), 100, 10 - 4)
	assert_str(m.timer_text).is_equal("6 LEFT")
