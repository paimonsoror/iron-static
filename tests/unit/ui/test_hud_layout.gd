class_name TestHudLayout
extends GdUnitTestSuite
## Styled, compacted battle HUD (V1-16, V1-25) at 1080x1920 and 1080x2400: nothing overlaps, icon buttons drawn
## <= 90 px with touch rects >= 126 px that do not overlap, text >= 38 px, total height <= 250 px, text contrast
## >= 4.5:1 on its plate, banner behavior and the pause icon swap.

const MIN_TOUCH: float = 126.0
const MAX_HUD_H: float = 252.0
const MIN_TIMER_H: float = 24.0
const MIN_TEXT: int = 38
const MIN_CONTRAST: float = 4.5


func _hud(height: float) -> Hud:
	var root: Control = auto_free(Control.new())
	root.size = Vector2(1080.0, height)
	add_child(root)
	var hud: Hud = (load("res://src/ui/hud.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	hud.show_values(12, 300, 70.0, 100.0, BigNum.from_float(12400.0), BigNum.from_float(3200.0))
	return hud


func _rect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size)


func _font_px(label: Label) -> int:
	return label.get_theme_font_size("font_size")


func _check(height: float) -> void:
	var hud: Hud = _hud(height)
	await await_idle_frame()
	await await_idle_frame()
	var top: Rect2 = _rect(hud.get_node("%TopPlate") as Control)
	var wave: Rect2 = _rect(hud.get_node("%WaveLabel") as Control)
	var timer: Rect2 = _rect(hud.get_node("%TimerBar") as Control)
	var timer_text: Rect2 = _rect(hud.get_node("%TimerLabel") as Control)
	var speed_text: Rect2 = _rect(hud.get_node("%SpeedLabel") as Control)
	var speed: Rect2 = _rect(hud.get_node("%SpeedButton") as Control)
	var pause: Rect2 = _rect(hud.get_node("%PauseButton") as Control)
	var integrity: Rect2 = _rect(hud.get_node("%IntegrityBar") as Control)
	var hp: Rect2 = _rect(hud.get_node("%HpLabel") as Control)
	var scrap: Rect2 = _rect(hud.get_node("%ScrapPlate") as Control)
	var data: Rect2 = _rect(hud.get_node("%DataPlate") as Control)
	var panel: Rect2 = _rect(hud.upgrade_panel())
	var screen := Rect2(0.0, 0.0, 1080.0, height)
	# Touch targets.
	var touch: Array[Rect2] = []
	for b: TouchButton in [hud.get_node("%SpeedButton"), hud.get_node("%PauseButton")]:
		var tr: Rect2 = b.touch_rect()
		assert_float(tr.size.x).is_greater_equal(MIN_TOUCH)
		assert_float(tr.size.y).is_greater_equal(MIN_TOUCH)
		assert_float(b.size.x).is_less_equal(90.0)
		touch.append(Rect2(b.global_position + tr.position, tr.size))
	assert_bool(touch[0].intersects(touch[1])).is_false()
	assert_float(maxf(scrap.end.y, data.end.y) - top.position.y).is_less_equal(MAX_HUD_H)
	# V1-27: the wave timer bar is a legible 24 px.
	assert_float(timer.size.y).is_greater_equal(MIN_TIMER_H)
	# Wave, time left and speed share one line.
	assert_float(absf(wave.get_center().y - timer_text.get_center().y)).is_less(1.0)
	assert_float(absf(wave.get_center().y - speed_text.get_center().y)).is_less(1.0)
	# Inside the screen and the top plate.
	for r: Rect2 in [top, speed, pause, integrity, scrap, data]:
		assert_bool(screen.encloses(r)).is_true()
	for r: Rect2 in [wave, timer, timer_text, speed_text, speed, pause]:
		assert_bool(top.encloses(r)).is_true()
	assert_bool(integrity.encloses(hp)).is_true()
	# Nothing overlaps.
	var top_items: Array[Rect2] = [wave, timer, timer_text, speed_text, speed, pause]
	for i: int in top_items.size():
		for j: int in range(i + 1, top_items.size()):
			assert_bool(top_items[i].intersects(top_items[j])).is_false()
	var blocks: Array[Rect2] = [top, integrity, scrap, data, panel]
	for i: int in blocks.size():
		for j: int in range(i + 1, blocks.size()):
			assert_bool(blocks[i].intersects(blocks[j])).is_false()
	# The number pocket is right of the segments: the label starts inside the pocket.
	var bar: SegmentedBar = hud.get_node("%IntegrityBar")
	assert_float(hp.position.x).is_greater_equal(integrity.end.x - bar.pocket_px - SegmentedBar.INSET)
	# Text sizes.
	for n: String in ["%WaveLabel", "%TimerLabel", "%SpeedLabel", "%HpLabel", "%ScrapLabel", "%DataLabel"]:
		assert_int(_font_px(hud.get_node(n) as Label)).is_greater_equal(MIN_TEXT)
	print(
		(
			"[hud layout %d] top %s integrity %s scrap %s data %s panel top %.0f"
			% [int(height), top, integrity, scrap, data, panel.position.y]
		)
	)


func test_layout_at_1080x1920() -> void:
	await _check(1920.0)


func test_layout_at_1080x2400() -> void:
	await _check(2400.0)


func test_text_contrast_on_plates_is_at_least_4_5() -> void:
	# Plates are PANEL-dark; the pocket is PLATE_SHADOW.
	var plate: Color = Palette.PANEL
	for c: Color in [Palette.AMBER, Palette.AMBER_GLOW, Palette.TEXT, Palette.SCRAP, Palette.DATA, Palette.TEXT_DIM]:
		assert_float(ThemeBuilder.contrast_ratio(c, plate)).is_greater_equal(MIN_CONTRAST)
	assert_float(ThemeBuilder.contrast_ratio(Palette.TEXT, Palette.PLATE_SHADOW)).is_greater_equal(MIN_CONTRAST)


func test_pause_icon_swaps_and_signals_still_fire() -> void:
	var hud: Hud = _hud(2400.0)
	var pause: Button = hud.get_node("%PauseButton")
	var first: Texture2D = pause.icon
	var seen: Array[bool] = []
	hud.pause_toggled.connect(func(p: bool) -> void: seen.append(p))
	pause.pressed.emit()
	assert_bool(pause.icon != first).is_true()
	pause.pressed.emit()
	assert_bool(pause.icon == first).is_true()
	assert_array(seen).is_equal([true, false])
	hud.set_speed(2)
	assert_str((hud.get_node("%SpeedLabel") as Label).text).is_equal("2x")
	assert_int(hud.speed()).is_equal(2)


func test_banner_plays_on_wave_change_and_boss_variant() -> void:
	var hud: Hud = _hud(2400.0)
	hud.reduce_motion = true
	var banner: WaveBanner = hud.wave_banner()
	assert_bool(banner.is_playing()).is_true()  # wave 12 on the first values
	banner.stop()
	assert_bool(banner.is_playing()).is_false()
	hud.show_values(12, 400, 70.0, 100.0, BigNum.zero(), BigNum.zero())
	assert_bool(banner.is_playing()).is_false()  # same wave: no new banner
	hud.show_values(13, 0, 70.0, 100.0, BigNum.zero(), BigNum.zero())
	assert_bool(banner.is_playing()).is_true()
	banner.stop()
	hud.show_values(25, 0, 70.0, 100.0, BigNum.zero(), BigNum.zero(), true)
	assert_bool(banner.is_playing()).is_true()
	assert_int(banner.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


func test_banner_timeline_constants() -> void:
	assert_float(WaveBanner.total_s(false)).is_equal_approx(0.35 + 0.08 + 0.8 + 0.25, 0.001)
	assert_float(WaveBanner.total_s(true)).is_equal_approx(0.8, 0.001)


func test_counters_roll_with_refresh_and_settle_on_the_exact_target() -> void:
	var hud: Hud = _hud(2400.0)
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	hud.refresh(world, 10.0)
	world.economy.scrap = BigNum.from_float(1000.0)
	hud.refresh(world, 10.2)
	var label: Label = hud.get_node("%ScrapLabel")
	assert_str(label.text).is_not_equal("SCRAP 1K")  # mid roll
	hud.refresh(world, 10.6)
	assert_str(label.text).is_equal("SCRAP 1K")


func test_speed_button_cycles_unlocked_speeds_and_shows_both_in_fall_back() -> void:
	var hud: Hud = _hud(2400.0)
	var label: Label = hud.get_node("%SpeedLabel")
	var chosen: Label = hud.get_node("%TopBar/SpeedChosenLabel")
	var btn: Button = hud.get_node("%SpeedButton")
	btn.pressed.emit()
	assert_int(hud.speed()).is_equal(2)
	btn.pressed.emit()
	assert_int(hud.speed()).is_equal(1)  # 4x and 8x are locked: 1x, 2x only
	hud.set_best_timed(60)
	for expect: int in [2, 4, 8, 1]:
		btn.pressed.emit()
		assert_int(hud.speed()).is_equal(expect)
	hud.set_speed(8)
	assert_bool(chosen.visible).is_false()
	assert_str(label.text).is_equal("8x")
	var world: SimWorld = SimWorld.new(SimConfigLoader.load_default(5))
	world.cinder.hp = world.cinder.max_hp * 0.5
	hud.refresh(world, 0.0)
	assert_int(hud.effective_speed()).is_equal(2)
	assert_str(label.text).is_equal("2x")
	assert_bool(chosen.visible).is_true()
	assert_str(chosen.text).is_equal("8x")
	world.cinder.hp = world.cinder.max_hp * 0.78
	hud.refresh(world, 1.0)
	assert_int(hud.effective_speed()).is_equal(2)  # hysteresis
	world.cinder.hp = world.cinder.max_hp
	hud.refresh(world, 2.0)
	assert_int(hud.effective_speed()).is_equal(8)
	assert_bool(chosen.visible).is_false()
