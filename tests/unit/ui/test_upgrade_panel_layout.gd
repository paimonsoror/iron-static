class_name TestUpgradePanelLayout
extends GdUnitTestSuite
## Layout of the HUD upgrade panel at 1080x1920 and 1080x2400 (M2-10): nothing overlaps, touch targets >= 148 px.

const MIN_TOUCH: float = 148.0


func _layout(height: float) -> Hud:
	var root: Control = auto_free(Control.new())
	root.size = Vector2(1080.0, height)
	add_child(root)
	var packed: PackedScene = load("res://src/ui/hud.tscn")
	var hud: Hud = packed.instantiate()
	root.add_child(hud)
	var cfg: SimConfig = SimConfigLoader.load_default(1)
	cfg.best_wave_s1 = 999  # all five ARMS rows exist
	hud.upgrade_panel().bind(SimWorld.new(cfg))
	return hud


func _rect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size)


func _check(height: float) -> void:
	var hud: Hud = _layout(height)
	await await_idle_frame()
	await await_idle_frame()
	var panel: UpgradePanel = hud.upgrade_panel()
	var pr: Rect2 = _rect(panel)
	assert_float(pr.position.y).is_equal_approx(height * 0.56, 1.0)
	assert_float(pr.end.y).is_less_equal(height + 0.5)
	var tabs: Array[Rect2] = []
	for id: String in UpgradePanelModel.TAB_IDS:
		var b: Button = panel.get_node("%TabBar/Tab_" + id)
		assert_float(b.size.y).is_greater_equal(MIN_TOUCH)
		tabs.append(_rect(b))
	var buys: Array[Rect2] = []
	for k: int in 4:
		var b: Button = panel.get_node("%BuyBar/Buy_" + str(k))
		assert_float(b.size.y).is_greater_equal(MIN_TOUCH)
		buys.append(_rect(b))
	var scroll: Rect2 = _rect(panel.get_node("%Scroll") as Control)
	for t: Rect2 in tabs:
		assert_bool(pr.encloses(t)).is_true()
		for bb: Rect2 in buys:
			assert_bool(t.intersects(bb)).is_false()
		assert_bool(t.intersects(scroll)).is_false()
	for bb: Rect2 in buys:
		assert_bool(pr.encloses(bb)).is_true()
		assert_bool(bb.intersects(scroll)).is_false()
	for i: int in tabs.size() - 1:
		assert_bool(tabs[i].intersects(tabs[i + 1])).is_false()
	assert_bool(pr.encloses(scroll)).is_true()
	# Rows: UpgradeRow.ROW_MIN_H tall, buy button >= 148 px, inside the row, rows do not overlap.
	var rows: Array[Rect2] = []
	for i: int in 5:
		var row: UpgradeRow = panel.row_at(i)
		assert_bool(row.visible).is_true()
		assert_float(row.size.y).is_greater_equal(UpgradeRow.ROW_MIN_H)
		var cost: Button = row.get_node("%BuyButton")
		assert_float(cost.size.y).is_greater_equal(MIN_TOUCH)
		assert_float(cost.size.x).is_greater_equal(120.0 * ThemeBuilder.PX_PER_DP)
		assert_bool(_rect(row).encloses(_rect(cost))).is_true()
		rows.append(_rect(row))
	for i: int in rows.size() - 1:
		assert_bool(rows[i].intersects(rows[i + 1])).is_false()
	# At least two full rows are visible without scrolling; ARMS needs the scroll for the rest.
	assert_float(scroll.size.y).is_greater_equal(2.0 * UpgradeRow.ROW_MIN_H)
	var content: Control = panel.get_node("%RowsBox")
	assert_float(content.size.y).is_greater(scroll.size.y)
	print(
		(
			"[layout %d] panel %s scroll h %.0f visible rows %.1f"
			% [int(height), pr, scroll.size.y, scroll.size.y / (UpgradeRow.ROW_MIN_H + 8.0)]
		)
	)


func test_layout_at_1080x1920() -> void:
	await _check(1920.0)


func test_layout_at_1080x2400() -> void:
	await _check(2400.0)
