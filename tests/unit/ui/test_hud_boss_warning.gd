class_name TestHudBossWarning
extends GdUnitTestSuite
## Boss chevron and banner (M4-17): the chip shows at waves 7-9 only, the spawn-edge chevron lives from BOSS_WARNING
## to the spawn, BOSS_SPAWNED raises boss_arrived, the pure edge point lands on the field border.

const SCENE: PackedScene = preload("res://src/ui/hud.tscn")


func _hud() -> Hud:
	var root: Control = auto_free(Control.new())
	root.size = Vector2(1080.0, 2400.0)
	add_child(root)
	var h: Hud = SCENE.instantiate()
	root.add_child(h)
	return h


func _world(wave: int) -> SimWorld:
	var cfg: SimConfig = SimConfigLoader.load_default(7)
	cfg.debug_invulnerable = true
	var w := SimWorld.new(cfg)
	w.wave = wave
	return w


func test_chip_visible_at_waves_7_8_9_and_hidden_at_6_and_10() -> void:
	var h: Hud = _hud()
	var t: float = 1.0
	for wave: int in [6, 7, 8, 9, 10, 11]:
		var w: SimWorld = _world(wave)
		h.refresh(w, t)
		t += 1.0
		assert_bool(h.boss_warning().chip_shown()).is_equal(wave in [7, 8, 9])


func test_edge_chevron_from_warning_until_spawn_and_banner_event() -> void:
	var h: Hud = _hud()
	var view: HudBossWarning = h.boss_warning()
	var arrived: Array[int] = [0]
	view.boss_arrived.connect(func() -> void: arrived[0] += 1)
	var w: SimWorld = _world(10)
	h.refresh(w, 1.0)
	assert_bool(view.edge_shown()).is_false()
	var warn_tick: int = -1
	var t: float = 2.0
	for i: int in 140:
		w.step()
		h.refresh(w, t)
		t += 1.0
		if warn_tick < 0 and view.edge_shown():
			warn_tick = w.tick
			assert_int(view.warned_angle()).is_between(0, SinCosTable.SIZE - 1)
	assert_int(warn_tick).is_greater(0)
	assert_bool(view.edge_shown()).is_false()
	assert_int(arrived[0]).is_equal(1)
	assert_bool(h.wave_banner().is_playing()).is_true()


func test_edge_point_lies_on_the_inset_field_border() -> void:
	var field := Rect2(0.0, 200.0, 1000.0, 1200.0)
	var c: Vector2 = field.get_center()
	var right: Vector2 = HudBossWarning.edge_point(field, 0, 50.0)
	assert_float(right.x).is_equal_approx(950.0, 0.01)
	assert_float(right.y).is_equal_approx(c.y, 0.01)
	var down: Vector2 = HudBossWarning.edge_point(field, SinCosTable.SIZE >> 2, 50.0)
	assert_float(down.y).is_equal_approx(field.end.y - 50.0, 0.5)
	for a: int in [100, 700, 1500, 2600, 3900]:
		var p: Vector2 = HudBossWarning.edge_point(field, a, 50.0)
		var on_x: bool = absf(p.x - 50.0) < 0.5 or absf(p.x - 950.0) < 0.5
		var on_y: bool = absf(p.y - 250.0) < 0.5 or absf(p.y - (field.end.y - 50.0)) < 0.5
		assert_bool(on_x or on_y).is_true()


func test_chip_visible_helper() -> void:
	for n: int in [-1, 0, 4, 10]:
		assert_bool(HudBossWarning.chip_visible(n)).is_false()
	for n: int in [1, 2, 3]:
		assert_bool(HudBossWarning.chip_visible(n)).is_true()
