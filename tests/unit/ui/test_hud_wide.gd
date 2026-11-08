class_name TestHudWide
extends GdUnitTestSuite
## V1-28: the real HUD in both layouts: portrait is unchanged (scene defaults), wide docks the panel right as a full
## height column and confines the top bar to the field column, both honor safe margins, the field rect follows the
## layout, and a fold or unfold mid-run keeps the panel usable (hold ends cleanly, tooltip survives).

const SCENE: PackedScene = preload("res://src/ui/hud.tscn")
const BAR_MAX: float = 1080.0

var _vp: SubViewport = null
var _root: Control = null
var _hud: Hud = null
var _battle: BattleView = null
var _rects: Array[Rect2] = []


func _setup(size: Vector2) -> void:
	_vp = auto_free(SubViewport.new())
	_vp.size = Vector2i(size)
	add_child(_vp)
	_root = Control.new()
	_root.size = size
	_vp.add_child(_root)
	_battle = (load("res://src/view/battle_view.tscn") as PackedScene).instantiate()
	_root.add_child(_battle)
	_hud = SCENE.instantiate()
	_hud.field_rect_changed.connect(_battle.set_field_rect)
	_hud.field_rect_changed.connect(func(r: Rect2) -> void: _rects.append(r))
	_root.add_child(_hud)
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.best_wave_s1 = 99
	var w := SimWorld.new(cfg)
	w.economy.scrap = BigNum.from_float(1.0e9)
	_hud.upgrade_panel().bind(w)
	await _settle()


func _resize(size: Vector2) -> void:
	_vp.size = Vector2i(size)
	_root.size = size
	await _settle()


func _settle() -> void:
	await await_idle_frame()
	await await_idle_frame()
	await await_idle_frame()


func _panel_rect() -> Rect2:
	var p: UpgradePanel = _hud.upgrade_panel()
	return Rect2(p.global_position, p.size)


func _bar_rect() -> Rect2:
	var b: Control = _hud.get_node("%TopBar")
	return Rect2(b.global_position, b.size)


func test_portrait_is_the_scene_layout() -> void:
	await _setup(Vector2(1080.0, 2400.0))
	assert_int(_hud.layout_mode()).is_equal(LayoutMode.Mode.PORTRAIT)
	var panel: Rect2 = _panel_rect()
	assert_float(panel.position.x).is_equal(0.0)
	assert_float(panel.size.x).is_equal(1080.0)
	assert_float(panel.end.y).is_equal_approx(2400.0, 0.5)  # bottom panel, grows upward
	assert_float(panel.size.y).is_less_equal(2400.0 * Hud.PANEL_MAX_SHARE + 1.0)
	assert_vector(_bar_rect().position).is_equal(Vector2.ZERO)
	assert_float(_bar_rect().size.x).is_equal(1080.0)
	var f: Rect2 = _rects[_rects.size() - 1]
	assert_float(f.position.x).is_equal(0.0)
	assert_float(f.size.x).is_equal(1080.0)
	assert_float(f.end.y).is_equal_approx(panel.position.y, 0.5)
	var p: UpgradePanel = _hud.upgrade_panel()
	assert_float(p.anchor_left).is_equal(0.0)
	assert_float(p.anchor_top).is_equal(1.0)
	var banner: Control = _hud.get_node("%WaveBanner")
	assert_float(banner.offset_left).is_equal(0.0)
	assert_float(banner.offset_right).is_equal(0.0)


func test_wide_docks_the_panel_and_confines_the_bar() -> void:
	await _setup(Vector2(1990.0, 1920.0))
	assert_int(_hud.layout_mode()).is_equal(LayoutMode.Mode.WIDE)
	var panel: Rect2 = _panel_rect()
	assert_float(panel.size.y).is_equal_approx(1920.0, 0.5)
	assert_float(panel.position.y).is_equal_approx(0.0, 0.5)
	assert_float(panel.end.x).is_equal_approx(1990.0, 0.5)
	assert_float(panel.size.x / 1990.0).is_between(0.34, 0.42)
	var bar: Rect2 = _bar_rect()
	assert_float(bar.size.x).is_less_equal(BAR_MAX + 0.5)
	assert_float(bar.end.x).is_less_equal(panel.position.x + 0.5)
	# bars must not stretch: far narrower than the 1990 px they got before
	assert_float(bar.size.x).is_less(1990.0 * 0.6)
	# the plates stay inside the bar
	for node: String in ["%TopPlate", "%IntegrityBar", "%ScrapPlate", "%DataPlate"]:
		var c: Control = _hud.get_node(node)
		var r := Rect2(c.global_position, c.size)
		assert_float(r.position.x).is_greater_equal(bar.position.x - 0.5)
		assert_float(r.end.x).is_less_equal(bar.end.x + 0.5)
	# the list fills the column: scroll area reaches near the panel bottom (many more rows than a bottom panel)
	var scroll: Control = _hud.upgrade_panel().get_node("%Scroll")
	assert_float(scroll.size.y).is_greater(1500.0)


func test_wide_field_rect_is_left_of_the_panel() -> void:
	await _setup(Vector2(1990.0, 1920.0))
	var f: Rect2 = _rects[_rects.size() - 1]
	var panel: Rect2 = _panel_rect()
	assert_float(f.position.x).is_equal(0.0)
	assert_float(f.end.x).is_equal_approx(panel.position.x, 0.5)
	assert_float(f.end.y).is_equal_approx(1920.0, 0.5)
	assert_float(f.position.y).is_between(200.0, 260.0)
	assert_float(_hud.field_rect().size.x).is_equal_approx(f.size.x, 0.5)


func test_safe_margins_in_both_layouts() -> void:
	await _setup(Vector2(1990.0, 1920.0))
	_hud.apply_safe_margins(Vector4(30.0, 90.0, 50.0, 40.0))
	await _settle()
	var panel: Rect2 = _panel_rect()
	assert_float(panel.end.x).is_equal_approx(1940.0, 0.5)
	assert_float(panel.position.y).is_equal_approx(90.0, 0.5)
	assert_float(panel.end.y).is_equal_approx(1880.0, 0.5)
	assert_float(_bar_rect().position.y).is_equal_approx(90.0, 0.5)
	assert_float(_bar_rect().position.x).is_greater_equal(30.0 - 0.5)
	var f: Rect2 = _rects[_rects.size() - 1]
	assert_float(f.position.y).is_greater_equal(90.0 + 200.0)
	assert_float(f.end.y).is_equal_approx(1880.0, 0.5)
	await _resize(Vector2(1080.0, 2400.0))
	assert_int(_hud.layout_mode()).is_equal(LayoutMode.Mode.PORTRAIT)
	panel = _panel_rect()
	assert_float(panel.position.x).is_equal_approx(30.0, 0.5)
	assert_float(panel.end.x).is_equal_approx(1030.0, 0.5)
	assert_float(panel.end.y).is_equal_approx(2360.0, 0.5)
	assert_float(_bar_rect().position.y).is_equal_approx(90.0, 0.5)


func test_switching_modes_both_ways_restores_the_portrait_rects() -> void:
	await _setup(Vector2(1080.0, 2400.0))
	var panel_before: Rect2 = _panel_rect()
	var bar_before: Rect2 = _bar_rect()
	var field_before: Rect2 = _rects[_rects.size() - 1]
	await _resize(Vector2(1990.0, 1920.0))
	assert_int(_hud.layout_mode()).is_equal(LayoutMode.Mode.WIDE)
	await _resize(Vector2(1080.0, 2400.0))
	assert_int(_hud.layout_mode()).is_equal(LayoutMode.Mode.PORTRAIT)
	assert_float(_panel_rect().position.y).is_equal_approx(panel_before.position.y, 0.5)
	assert_float(_panel_rect().size.x).is_equal_approx(panel_before.size.x, 0.5)
	assert_float(_bar_rect().size.x).is_equal_approx(bar_before.size.x, 0.5)
	var f: Rect2 = _rects[_rects.size() - 1]
	assert_float(f.size.x).is_equal_approx(field_before.size.x, 0.5)
	assert_float(f.end.y).is_equal_approx(field_before.end.y, 0.5)


func test_resize_inside_the_hysteresis_band_keeps_the_layout() -> void:
	await _setup(Vector2(1990.0, 1920.0))
	await _resize(Vector2(1440.0 + 0.0, 1920.0))  # aspect 0.75: wide stays wide
	assert_int(_hud.layout_mode()).is_equal(LayoutMode.Mode.WIDE)
	await _resize(Vector2(1300.0, 1920.0))  # 0.677: below the exit threshold
	assert_int(_hud.layout_mode()).is_equal(LayoutMode.Mode.PORTRAIT)
	await _resize(Vector2(1440.0, 1920.0))  # 0.75: portrait stays portrait
	assert_int(_hud.layout_mode()).is_equal(LayoutMode.Mode.PORTRAIT)


func _center(c: Control) -> Vector2:
	var r: Rect2 = c.get_global_rect()
	return r.position + r.size * 0.5


func _mouse(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.position = pos
	e.global_position = pos
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_vp.push_input(e, true)


func _motion(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	_vp.push_input(e, true)


func test_hold_to_buy_survives_a_layout_switch() -> void:
	await _setup(Vector2(1080.0, 2400.0))
	var got: Array[Vector2i] = []
	_hud.upgrade_panel().buy_requested.connect(func(i: int, c: int) -> void: got.append(Vector2i(i, c)))
	var row: UpgradeRow = _hud.upgrade_panel().row_at(0)
	var pos: Vector2 = _center(row.get_node("%BuyButton") as Control)
	_motion(pos)
	_mouse(pos, true)
	row.advance_hold(0.4)
	assert_int(got.size()).is_equal(1)
	await _resize(Vector2(1990.0, 1920.0))  # unfold mid-hold: the rows moved, the hold ends without a stray buy
	var n: int = got.size()
	row.advance_hold(1.0)
	assert_int(got.size()).is_equal(n)
	_mouse(pos, false)
	assert_int(got.size()).is_equal(n)
	# a new hold in the wide layout works from scratch
	var pos2: Vector2 = _center(row.get_node("%BuyButton") as Control)
	_motion(pos2)
	_mouse(pos2, true)
	row.advance_hold(0.4)
	assert_int(got.size()).is_equal(n + 1)
	_mouse(pos2, false)


func test_tooltip_survives_a_layout_switch() -> void:
	await _setup(Vector2(1080.0, 2400.0))
	var row: UpgradeRow = _hud.upgrade_panel().row_at(0)
	row.toggle_tooltip()
	await _settle()
	assert_bool(row.is_tooltip_visible()).is_true()
	await _resize(Vector2(1990.0, 1920.0))
	assert_bool(row.is_tooltip_visible()).is_true()
	var tip: Control = row.get_parent().get_child(row.get_index() + 1)
	var panel: Rect2 = _panel_rect()
	assert_bool(panel.encloses(tip.get_global_rect().grow(-1.0))).is_true()
	row.toggle_tooltip()
	assert_bool(row.is_tooltip_visible()).is_false()
	row.toggle_tooltip()
	await _resize(Vector2(1080.0, 2400.0))
	assert_bool(row.is_tooltip_visible()).is_true()


func test_cinder_centers_in_the_field_column_through_the_hud_signal() -> void:
	await _setup(Vector2(1990.0, 1920.0))
	var f: Rect2 = _hud.field_rect()
	assert_float(_battle.position.x).is_equal_approx(f.get_center().x, 0.5)
	assert_float(_battle.position.y).is_equal_approx(f.get_center().y, 0.5)
	assert_float(_battle.position.x).is_less(1990.0 * 0.5)
	await _resize(Vector2(1080.0, 2400.0))
	f = _hud.field_rect()
	assert_float(_battle.position.x).is_equal_approx(540.0, 0.5)
	assert_float(_battle.position.y).is_equal_approx(f.get_center().y, 0.5)
