class_name TestTitleScreen
extends GdUnitTestSuite
## M3-28 TitleScreen scene: node tree per tier, reduce motion, hero frame, buttons and signals, quit confirm, fade,
## layout inside the safe area, draw budget (structural; the measured counts are in the capture metrics).

const SCENE: String = "res://src/ui/title/title_screen.tscn"
const HIGH := VisualQuality.Tier.HIGH
const MID := VisualQuality.Tier.MID
const LOW := VisualQuality.Tier.LOW

var _spy: SpyAudioDirector
var _old_saves: SaveService


func before_test() -> void:
	_spy = auto_free(SpyAudioDirector.new())
	AudioHooks.override = _spy
	_old_saves = Game.saves


func after_test() -> void:
	AudioHooks.override = null
	Game.saves = _old_saves


func _make(size: Vector2 = Vector2(1080.0, 2400.0)) -> TitleScreen:
	var host := Control.new()
	host.size = size
	add_child(host)
	auto_free(host)
	var s: TitleScreen = (load(SCENE) as PackedScene).instantiate()
	host.add_child(s)
	return s


func test_low_has_one_smoke_layer_and_no_emitter() -> void:
	var s: TitleScreen = _make()
	s.show_state(LOW, false, true, "vanguard")
	assert_int(s.fx().visible_smoke_count()).is_equal(1)
	assert_bool(s.fx().has_emitter()).is_false()
	s.advance(2.0)
	s.advance(2.0)
	assert_int(s.fx().ember_count()).is_equal(0)
	assert_bool(s.scanlines_visible()).is_false()


func test_mid_two_layers_high_three_plus_emitter() -> void:
	var s: TitleScreen = _make()
	s.show_state(MID, false, true, "vanguard")
	assert_int(s.fx().visible_smoke_count()).is_equal(2)
	assert_bool(s.fx().has_emitter()).is_true()
	s.show_state(HIGH, false, true, "vanguard")
	assert_int(s.fx().visible_smoke_count()).is_equal(3)
	assert_bool(s.fx().has_emitter()).is_true()
	for i: int in 40:
		s.advance(0.1)
	assert_int(s.fx().ember_count()).is_greater(0)
	assert_bool(s.scanlines_visible()).is_true()


func test_reduce_motion_freezes_drift_shimmer_embers_and_flare() -> void:
	var s: TitleScreen = _make()
	s.show_state(HIGH, true, true, "vanguard")
	s.advance(5.0)
	var layer: Sprite2D = s.fx().parallax.layers[3]
	var p1: Vector2 = layer.position
	s.advance(20.0)
	s.advance(20.0)
	assert_vector(layer.position).is_equal(p1)
	assert_bool(s.fx().embers_active()).is_false()
	assert_int(s.fx().ember_count()).is_equal(0)
	assert_bool(s.fx().flare_active()).is_false()
	assert_float(s.logo().uniform("tear")).is_equal(0.0)
	assert_float(s.logo().uniform("sweep_strength")).is_equal(0.0)
	assert_bool(s.logo().is_tearing()).is_false()
	assert_bool(s.scanlines_visible()).is_false()


func test_motion_on_logo_tear_stays_within_the_cap() -> void:
	var s: TitleScreen = _make()
	s.show_state(HIGH, false, true, "vanguard")
	for i: int in 30:
		s.logo().force_tear()
		var dx: float = s.logo().uniform("tear_dx")
		assert_bool(TitleModel.tear_px(dx) <= TitleModel.MAX_TEAR_PX).is_true()


func test_hero_follows_the_requested_frame() -> void:
	var s: TitleScreen = _make()
	for fid: String in ["striker", "bulwark", "vanguard"]:
		s.show_state(HIGH, false, true, fid)
		assert_str(s.fx().frame_id_shown()).is_equal(fid)


func test_buttons_depend_on_progress_and_emit_signals() -> void:
	var s: TitleScreen = _make()
	s.show_state(HIGH, false, false, "vanguard")
	assert_array(s.buttons().rows()).is_equal(["new_game", "settings"])
	s.show_state(HIGH, false, true, "vanguard")
	assert_array(s.buttons().rows()).is_equal(["continue", "new_game", "settings"])
	var got: Array[String] = []
	s.continue_pressed.connect(func() -> void: got.append("continue"))
	s.new_game_pressed.connect(func() -> void: got.append("new_game"))
	s.settings_pressed.connect(func() -> void: got.append("settings"))
	for id: String in ["continue", "new_game", "settings"]:
		s.buttons().pressed.emit(id)
	assert_array(got).is_equal(["continue", "new_game", "settings"])
	assert_int(_spy.sfx.size()).is_equal(3)


func test_back_opens_and_closes_the_quit_confirm() -> void:
	var s: TitleScreen = _make()
	s.show_state(HIGH, false, true, "vanguard")
	var quits: Array[int] = []
	s.quit_confirmed.connect(func() -> void: quits.append(1))
	assert_bool(s.on_back()).is_true()
	assert_bool(s.quit_box_visible()).is_true()
	assert_bool(s.buttons().visible).is_false()
	assert_bool(s.on_back()).is_true()
	assert_bool(s.quit_box_visible()).is_false()
	assert_bool(s.buttons().visible).is_true()
	@warning_ignore("return_value_discarded")
	s.on_back()
	var box: VBoxContainer = s.content.get_child(s.content.get_child_count() - 1)
	var yes: Button = box.get_child(1)
	yes.pressed.emit()
	assert_array(quits).is_equal([1])


func test_enter_fades_in_once_and_starts_menu_audio() -> void:
	Game.saves = null
	var s: TitleScreen = _make()
	s.enter()
	assert_int(_spy.menu_audio_starts).is_equal(1)
	s.advance(0.0)
	assert_float(s.fade_alpha()).is_equal(1.0)
	s.advance(0.3)
	assert_float(s.fade_alpha()).is_between(0.05, 0.95)
	s.advance(0.4)
	assert_float(s.fade_alpha()).is_equal(0.0)
	s.leave()
	s.enter()
	s.advance(0.0)
	assert_float(s.fade_alpha()).is_equal(0.0)
	assert_bool(s.is_processing()).is_true()
	s.leave()
	assert_bool(s.is_processing()).is_false()


func _assert_layout(s: TitleScreen, safe: Vector4) -> void:
	s.apply_safe_margins(safe)
	var b: TitleButtons = s.buttons()
	var area := Rect2(safe.x, safe.y, s.size.x - safe.x - safe.z, s.size.y - safe.y - safe.w)
	var r := Rect2(b.position, b.size)
	assert_bool(area.encloses(r)).override_failure_message("buttons %s outside %s" % [r, area]).is_true()
	for i: int in b.rows().size():
		assert_float(b.row_rect(i).size.y).is_greater_equal(148.0)
	var logo_top: float = s.logo().position.y - TitleModel.LOGO_HALF_H
	assert_bool(logo_top >= safe.y).is_true()


func test_layout_inside_safe_area_at_three_sizes() -> void:
	var s: TitleScreen = _make(Vector2(1080.0, 2400.0))
	s.show_state(HIGH, false, true, "vanguard")
	_assert_layout(s, Vector4.ZERO)
	var s2: TitleScreen = _make(Vector2(1080.0, 2341.0))
	s2.show_state(HIGH, false, true, "vanguard")
	_assert_layout(s2, Vector4(0.0, 110.0, 0.0, 70.0))
	var s3: TitleScreen = _make(Vector2(1990.0, 1920.0))
	s3.show_state(HIGH, false, true, "vanguard")
	_assert_layout(s3, Vector4(0.0, 0.0, 0.0, 0.0))
	assert_float(s3.buttons().size.x).is_less_equal(1080.0)
	assert_float(s3.buttons().get_rect().get_center().x).is_equal_approx(995.0, 1.0)


func _draw_estimate(n: Node) -> int:
	var total: int = 0
	var ci: CanvasItem = n as CanvasItem
	if ci != null and not ci.visible:
		return 0
	if n is Sprite2D or n is ColorRect:
		total += 1
	elif n is TitleButtons:
		total += 2
	elif n is ParticleRenderer:
		total += 1  # the additive pool; the smoke pool is empty (skipped)
	for c: Node in n.get_children():
		total += _draw_estimate(c)
	return total


func test_draw_budget_per_tier() -> void:
	var s: TitleScreen = _make()
	s.show_state(HIGH, false, true, "vanguard")
	var high: int = _draw_estimate(s.fx()) + 2 + 1 + 1  # buttons, logo, scanline overlay
	s.show_state(LOW, false, true, "vanguard")
	var low: int = _draw_estimate(s.fx()) + 2 + 1
	assert_int(high).is_less_equal(15)
	assert_int(low).is_less(high)
