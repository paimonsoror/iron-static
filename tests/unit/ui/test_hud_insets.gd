class_name TestHudInsets
extends GdUnitTestSuite
## V1-25: the HUD reports the open field to the battle view: top = HUD bottom edge, bottom = screen height minus the
## panel top, on ready, on resize and when the panel or safe margins change.


func _hud(height: float) -> Array:
	var root: Control = auto_free(Control.new())
	root.size = Vector2(1080.0, height)
	add_child(root)
	var hud: Hud = (load("res://src/ui/hud.tscn") as PackedScene).instantiate()
	var seen: Array[Vector2] = []
	hud.field_insets_changed.connect(func(t: float, b: float) -> void: seen.append(Vector2(t, b)))
	root.add_child(hud)
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.best_wave_s1 = 99
	hud.upgrade_panel().bind(SimWorld.new(cfg))
	return [root, hud, seen]


func _expected(hud: Hud, height: float) -> Vector2:
	var sp: Control = hud.get_node("%ScrapPlate")
	var dp: Control = hud.get_node("%DataPlate")
	var panel: Rect2 = Rect2(hud.upgrade_panel().global_position, hud.upgrade_panel().size)
	return Vector2(maxf(sp.global_position.y + sp.size.y, dp.global_position.y + dp.size.y), height - panel.position.y)


func test_insets_match_hud_and_panel_rects() -> void:
	var parts: Array = _hud(2400.0)
	var hud: Hud = parts[1]
	var seen: Array[Vector2] = parts[2]
	await await_idle_frame()
	await await_idle_frame()
	assert_int(seen.size()).is_greater(0)
	var last: Vector2 = seen[seen.size() - 1]
	var want: Vector2 = _expected(hud, 2400.0)
	assert_float(last.x).is_equal_approx(want.x, 1.0)
	assert_float(last.y).is_equal_approx(want.y, 1.0)
	assert_float(last.x).is_between(200.0, 260.0)
	assert_float(last.y).is_less_equal(2400.0 * 0.36 + 1.0)


func test_safe_margins_and_resize_update_the_insets() -> void:
	var parts: Array = _hud(2400.0)
	var root: Control = parts[0]
	var hud: Hud = parts[1]
	var seen: Array[Vector2] = parts[2]
	await await_idle_frame()
	await await_idle_frame()
	var before: Vector2 = seen[seen.size() - 1]
	hud.apply_safe_margins(Vector4(0.0, 100.0, 0.0, 60.0))
	await await_idle_frame()
	await await_idle_frame()
	var after: Vector2 = seen[seen.size() - 1]
	assert_float(after.x).is_equal_approx(before.x + 100.0, 1.0)
	assert_float(after.y).is_equal_approx(before.y + 60.0, 1.0)
	root.size = Vector2(1080.0, 1920.0)
	await await_idle_frame()
	await await_idle_frame()
	var small: Vector2 = seen[seen.size() - 1]
	var want: Vector2 = _expected(hud, 1920.0)
	assert_float(small.x).is_equal_approx(want.x, 1.0)
	assert_float(small.y).is_equal_approx(want.y, 1.0)
