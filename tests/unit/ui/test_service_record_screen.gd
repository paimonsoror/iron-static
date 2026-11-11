class_name TestServiceRecordScreen
extends GdUnitTestSuite
## SERVICE RECORD screen: sections and rows, enemy names, number format, durations, and that a touch drag starting on a
## stat row scrolls the list (read-only controls must not swallow the drag).

var _vp: SubViewport = null


func _profile() -> PlayerProfile:
	var p := PlayerProfile.fresh(1794268800, "t")
	p.runs_total = 5
	p.lifetime_data = BigNum.from_float(5000.0)
	p.data = BigNum.from_float(1200.0)
	p.foundry = {"laser_output": 7, "cycle_rate": 3}
	p.best_wave["1"] = 22
	p.best_wave_by_mode["purge"] = {"1": 9}
	ServiceRecord.ensure(p, FakeClock.new(1794268800))
	var t := RunTotals.new()
	t.detail = RunTotals.Detail.FULL
	t.frame_id = "vanguard"
	t.wave = 22
	t.waves_cleared = 21
	t.ticks = 30 * 3725
	t.kills = {"skitter": 12345, "boss_hulk": 3}
	t.bosses = 3
	t.shots = 800
	t.crits = 187
	t.hit_max = 4321
	t.damage = BigNum.from_float(2.5e6)
	ServiceRecord.commit_run(p, t)
	ServiceRecord.note_seconds(p, 12 * 3600 + 5 * 60 + 40)
	p.runs_total = 6  # banking the run above counted it in the profile too
	return p


func _screen(size: Vector2i, profile: PlayerProfile) -> ServiceRecordScreen:
	_vp = auto_free(SubViewport.new())
	_vp.size = size
	add_child(_vp)
	var s: ServiceRecordScreen = (load("res://src/ui/record/service_record_screen.tscn") as PackedScene).instantiate()
	s.setup(profile)
	_vp.add_child(s)
	s.size = Vector2(size)
	return s


func _row_value(s: ServiceRecordScreen, label_text: String) -> String:
	for i: int in s.name_labels.size():
		if s.name_labels[i].text == label_text:
			return s.value_labels[i].text
	return "<missing %s>" % label_text


func test_builds_every_section_with_the_game_s_enemy_names() -> void:
	var missing: int = Strings.missing_count
	var s: ServiceRecordScreen = _screen(Vector2i(1080, 1920), _profile())
	await await_idle_frame()
	assert_int(s.model.sections.size()).is_equal(5)
	var titles: Array[String] = []
	for sec: RecordSection in s.model.sections:
		titles.append(sec.title)
	assert_array(titles).contains_exactly(["GENERAL", "COMBAT", "MACHINES DESTROYED", "ECONOMY", "FRAMES"])
	assert_str(s.heading.text).is_equal("SERVICE RECORD")
	assert_str(s.since_label.text).is_equal("TRACKED SINCE 2026-11-10")
	var ids: Array[String] = []
	for def: EnemyDef in SimConfigLoader.load_default(1).enemies:
		ids.append(def.id)
		var shown: String = Strings.get_text("enemy.name." + def.id)  # the Intel / Results name
		assert_bool(_row_value(s, shown).begins_with("<missing")).is_false()
	assert_int(ids.size()).is_greater_equal(5)
	assert_str(_row_value(s, "SKITTER")).is_equal("12.3K")
	assert_str(_row_value(s, "HULK")).is_equal("3")
	assert_str(_row_value(s, "DART")).is_equal("0")
	assert_int(Strings.missing_count).is_equal(missing)


func test_general_combat_economy_and_frame_rows() -> void:
	var s: ServiceRecordScreen = _screen(Vector2i(1080, 1920), _profile())
	await await_idle_frame()
	assert_str(_row_value(s, "TIME PLAYED")).is_equal("12h 05m")
	assert_str(_row_value(s, "TIME DEPLOYED")).is_equal("1h 02m")
	assert_str(_row_value(s, "LONGEST DEPLOYMENT")).is_equal("1h 02m")
	assert_str(_row_value(s, "DEPLOYMENTS")).is_equal("6")  # 5 banked before tracking began, 1 since
	assert_str(_row_value(s, "TIMED DEPLOYMENTS")).is_equal("1")
	assert_str(_row_value(s, "EARLIER DEPLOYMENTS")).is_equal("5")
	assert_str(_row_value(s, "BEST WAVE TIMED")).is_equal("W22")
	assert_str(_row_value(s, "BEST WAVE PURGE")).is_equal("W9")
	assert_str(_row_value(s, "WAVES CLEARED")).is_equal("21")
	assert_str(_row_value(s, "MACHINES DESTROYED")).is_equal("12.3K")
	assert_str(_row_value(s, "BOSSES DESTROYED")).is_equal("3")
	assert_str(_row_value(s, "SHOTS FIRED")).is_equal("800")
	assert_str(_row_value(s, "CRIT RATE")).is_equal("23.3%")
	assert_str(_row_value(s, "DAMAGE DEALT")).is_equal("2.5M")
	assert_str(_row_value(s, "HIGHEST SINGLE HIT")).is_equal("4.32K")
	assert_str(_row_value(s, "DATA EARNED")).is_equal("5K")
	assert_str(_row_value(s, "DATA SPENT IN FOUNDRY")).is_equal("3.8K")
	assert_str(_row_value(s, "FOUNDRY LEVELS BOUGHT")).is_equal("10")
	assert_str(_row_value(s, "VANGUARD")).is_equal("1 RUNS  BEST W22")
	assert_str(_row_value(s, "BULWARK")).is_equal("-")  # a frame never deployed
	assert_bool(s.seeded_label.visible).is_true()  # runs_total was set before the record existed


func test_numbers_follow_the_number_format_setting() -> void:
	var old: int = NumberFormat.style
	NumberFormat.style = NumberFormat.SCIENTIFIC
	var s: ServiceRecordScreen = _screen(Vector2i(1080, 1920), _profile())
	await await_idle_frame()
	var sci: String = _row_value(s, "SKITTER")
	NumberFormat.style = old
	assert_str(sci).is_not_equal("12.3K")
	assert_str(sci).contains("e")


func test_seeded_and_gap_notes_show_only_when_they_apply() -> void:
	var p := PlayerProfile.new()
	p.runs_total = 2
	ServiceRecord.ensure(p, FakeClock.new(1794268800))
	ServiceRecord.commit_run(p, RunTotals.new())  # a summary-only run: one gap
	var s: ServiceRecordScreen = _screen(Vector2i(1080, 1920), p)
	await await_idle_frame()
	assert_bool(s.seeded_label.visible).is_true()
	assert_bool(s.gaps_label.visible).is_true()
	assert_str(s.gaps_label.text).contains("1 deployment(s)")
	assert_str(_row_value(s, "TIME PLAYED")).is_equal("0s")
	assert_str(_row_value(s, "CRIT RATE")).is_equal("-")


func test_duration_text() -> void:
	assert_str(RecordModel.duration_text(0)).is_equal("0s")
	assert_str(RecordModel.duration_text(59)).is_equal("59s")
	assert_str(RecordModel.duration_text(330)).is_equal("5m 30s")
	assert_str(RecordModel.duration_text(3600)).is_equal("1h 00m")
	assert_str(RecordModel.duration_text(12 * 3600 + 5 * 60 + 59)).is_equal("12h 05m")
	assert_str(RecordModel.duration_text(-4)).is_equal("0s")
	assert_str(RecordModel.rate_text(1, 3)).is_equal("33.3%")


func test_every_control_in_the_list_ignores_the_mouse() -> void:
	var s: ServiceRecordScreen = _screen(Vector2i(1080, 1920), _profile())
	await await_idle_frame()
	var stack: Array[Node] = [s.scroll]
	var seen: int = 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		if n is Control and n != s.scroll and not (n is ScrollBar):
			seen += 1
			assert_int((n as Control).mouse_filter).is_not_equal(Control.MOUSE_FILTER_STOP)
	assert_int(seen).is_greater(40)


# ---- touch scrolling ---------------------------------------------------------------------------------------------


func _send(e: InputEvent) -> void:
	_vp.push_input(e, true)


## What a finger produces on the phone: the raw touch events plus the emulated mouse events (project.godot emulates
## mouse from touch, and the ScrollContainer scrolls from the mouse side of the pair).
func _touch(pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = pos
	e.pressed = pressed
	_send(e)
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	m.pressed = pressed
	m.position = pos
	m.global_position = pos
	m.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	_send(m)


func _drag(from: Vector2, to: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = to
	e.relative = to - from
	e.screen_relative = to - from
	_send(e)
	var m := InputEventMouseMotion.new()
	m.position = to
	m.global_position = to
	m.relative = to - from
	m.screen_relative = to - from
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	_send(m)


## A finger swipe up by `dist` px in 10 steps, one frame apart (the ScrollContainer applies drags per frame).
func _swipe_up(start: Vector2, dist: float) -> void:
	_touch(start, true)
	var prev: Vector2 = start
	for i: int in 10:
		var p: Vector2 = start + Vector2(0.0, -dist * float(i + 1) / 10.0)
		_drag(prev, p)
		prev = p
		await await_millis(30)
	_touch(prev, false)
	await await_millis(30)


func _center(c: Control) -> Vector2:
	var r: Rect2 = c.get_global_rect()
	return r.position + r.size * 0.5


func test_a_touch_drag_that_starts_on_a_stat_row_scrolls_the_list() -> void:
	var s: ServiceRecordScreen = _screen(Vector2i(1080, 1920), _profile())
	await await_millis(500)
	var bar: ScrollBar = s.scroll.get_v_scroll_bar()
	assert_float(bar.max_value - bar.page).is_greater(300.0)  # the list is taller than the screen
	# a row of the first section that is on screen: both its name and its value
	for label: Label in [s.name_labels[1], s.value_labels[2], s.name_labels[3]]:
		s.scroll.scroll_vertical = 0
		var start: Vector2 = _center(label)
		assert_bool(s.scroll.get_global_rect().has_point(start)).is_true()
		await _swipe_up(start, 120.0)
		assert_int(s.scroll.scroll_vertical).is_greater(40)
	# the same drag over a kill row further down, after scrolling there
	s.scroll.scroll_vertical = 700
	var before: int = s.scroll.scroll_vertical
	var on_screen: Control = null
	for l: Label in s.name_labels:
		if s.scroll.get_global_rect().has_point(_center(l)) and l.text == "DART":
			on_screen = l
	if on_screen != null:
		await _swipe_up(_center(on_screen), 100.0)
		assert_int(s.scroll.scroll_vertical).is_greater(before)


func test_the_mouse_wheel_scrolls_over_a_row_too() -> void:
	var s: ServiceRecordScreen = _screen(Vector2i(1080, 1920), _profile())
	await await_millis(500)
	s.scroll.scroll_vertical = 0
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_DOWN
	e.position = _center(s.name_labels[1])
	e.global_position = e.position
	e.pressed = true
	_send(e)
	assert_int(s.scroll.scroll_vertical).is_greater(0)


func test_the_screen_fits_the_two_reference_sizes_without_clipping_the_back_button() -> void:
	for size: Vector2i in [Vector2i(1080, 1920), Vector2i(1080, 2400)]:
		var s: ServiceRecordScreen = _screen(size, _profile())
		await await_millis(300)
		var r: Rect2 = s.back_button.get_global_rect()
		assert_float(r.end.y).is_less_equal(float(size.y))
		assert_float(r.size.y).is_greater_equal(148.0)
		assert_float(s.scroll.size.y).is_greater(500.0)
		for l: Label in s.value_labels:
			assert_float(l.get_global_rect().end.x).is_less_equal(float(size.x))
		_vp.queue_free()
		await await_idle_frame()
