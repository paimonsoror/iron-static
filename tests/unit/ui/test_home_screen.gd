class_name TestHomeScreen
extends GdUnitTestSuite
## Home screen (M3-15): signals, touch targets, Foundry visibility, sound hooks and the three reference layouts.

const MIN_TOUCH: float = 148.0

var _spy: SpyAudioDirector = null


func before_test() -> void:
	_spy = auto_free(SpyAudioDirector.new())
	AudioHooks.override = _spy


func after_test() -> void:
	AudioHooks.override = null


func _profile(runs: int, best: int, data: String) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	p.runs_total = runs
	p.data = BigNum.parse(data)
	if best > 0:
		p.best_wave["1"] = best
	return p


func _screen(size: Vector2, safe: Vector4, profile: PlayerProfile) -> HomeScreen:
	var root: Control = auto_free(Control.new())
	root.size = size
	add_child(root)
	var s: HomeScreen = (load("res://src/ui/home/home_screen.tscn") as PackedScene).instantiate()
	s.setup(profile)
	root.add_child(s)
	s.size = size
	s.apply_safe_margins(safe)
	return s


func test_deploy_emits_once_per_tap_and_is_a_big_target() -> void:
	var s: HomeScreen = _screen(Vector2(1080.0, 2400.0), Vector4.ZERO, _profile(3, 14, "400"))
	var seen: Array[int] = [0]
	s.deploy_pressed.connect(func() -> void: seen[0] += 1)
	s.deploy_button.pressed.emit()
	assert_int(seen[0]).is_equal(1)
	assert_float(s.deploy_button.get_combined_minimum_size().y).is_greater_equal(MIN_TOUCH)
	assert_float(s.deploy_button.size.y).is_greater_equal(MIN_TOUCH)
	assert_array(_spy.sfx).contains_exactly(["sfx_ui_tap"])


func test_foundry_and_settings_signals_play_a_tap() -> void:
	var s: HomeScreen = _screen(Vector2(1080.0, 2400.0), Vector4.ZERO, _profile(3, 14, "400"))
	var seen: Array[String] = []
	s.foundry_pressed.connect(func() -> void: seen.append("foundry"))
	s.settings_pressed.connect(func() -> void: seen.append("settings"))
	s.nav_foundry.pressed.emit()
	s.hint_chip.pressed.emit()
	s.gear_button.pressed.emit()
	assert_array(seen).contains_exactly(["foundry", "foundry", "settings"])
	assert_int(_spy.sfx.size()).is_equal(3)
	assert_float(s.gear_button.size.y).is_greater_equal(MIN_TOUCH)
	assert_array(_spy.sfx).not_contains("sfx_ui_deny")


func test_frame_chip_emits_once_per_tap_with_a_tap_sound_and_hides_on_a_fresh_profile() -> void:
	var s: HomeScreen = _screen(Vector2(1080.0, 2400.0), Vector4.ZERO, _profile(3, 14, "400"))
	var seen: Array[int] = [0]
	s.frames_pressed.connect(func() -> void: seen[0] += 1)
	assert_bool(s.frame_button.visible).is_true()
	assert_str(s.frame_button.text).is_equal("FRAME: VANGUARD  >")
	s.frame_button.pressed.emit()
	assert_int(seen[0]).is_equal(1)
	assert_float(s.frame_button.size.y).is_greater_equal(MIN_TOUCH)
	assert_array(_spy.sfx).contains_exactly(["sfx_ui_tap"])
	var fresh: HomeScreen = _screen(Vector2(1080.0, 2400.0), Vector4.ZERO, _profile(0, 0, "0"))
	assert_bool(fresh.frame_button.visible).is_false()


func test_fresh_profile_hides_foundry_nav_and_chip() -> void:
	var s: HomeScreen = _screen(Vector2(1080.0, 2400.0), Vector4.ZERO, _profile(0, 0, "0"))
	assert_bool(s.nav_foundry.visible).is_false()
	assert_bool(s.nav_row.visible).is_false()
	assert_bool(s.hint_chip.visible).is_false()
	assert_str(s.best_label.text).is_equal(Strings.get_text("home.best_none"))


func test_after_a_run_the_nav_shows_foundry_and_enter_refreshes() -> void:
	var p: PlayerProfile = _profile(0, 0, "0")
	var s: HomeScreen = _screen(Vector2(1080.0, 2400.0), Vector4.ZERO, p)
	assert_bool(s.nav_foundry.visible).is_false()
	p.runs_total = 1
	p.data = BigNum.parse("400")
	s.enter()
	assert_bool(s.nav_foundry.visible).is_true()
	assert_bool(s.nav_row.visible).is_true()
	assert_bool(s.hint_chip.visible).is_true()
	assert_float(s.nav_foundry.size.y).is_greater_equal(MIN_TOUCH)


func test_no_systems_beyond_m3_are_shown() -> void:
	var s: HomeScreen = _screen(Vector2(1080.0, 2400.0), Vector4.ZERO, _profile(3, 14, "400"))
	var texts: PackedStringArray = PackedStringArray()
	_collect_texts(s, texts)
	var joined: String = " ".join(texts).to_lower()
	for word: String in ["flux", "cipher", "merit", "standby", "research", "ad "]:
		assert_bool(joined.contains(word)).is_false()


func test_layouts_keep_everything_inside_the_safe_column() -> void:
	var cases: Array = [
		[Vector2(1080.0, 2400.0), Vector4.ZERO],
		[Vector2(1080.0, 2341.0), Vector4(0.0, 130.0, 0.0, 48.0)],
		[Vector2(1990.0, 1920.0), Vector4.ZERO],
	]
	for c: Array in cases:
		var size: Vector2 = c[0]
		var safe: Vector4 = c[1]
		var s: HomeScreen = _screen(size, safe, _profile(3, 14, "400"))
		await get_tree().process_frame
		var col: Rect2 = s.column_rect()
		for n: Node in s.content.get_children():
			var ctl: Control = n as Control
			if ctl == null or not ctl.visible:
				continue
			var r := Rect2(ctl.global_position - s.global_position, ctl.size)
			assert_bool(col.grow(0.5).encloses(r)).is_true()
		var gear := Rect2(s.gear_button.position, s.gear_button.size)
		assert_bool(col.grow(0.5).encloses(gear)).is_true()
		# The heading label spans the column; its centered text must stay clear of the gear.
		var font: Font = s.heading.get_theme_font("font")
		var text_w: float = (
			font.get_string_size(s.heading.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, HomeScreen.HEADING_PX).x
		)
		var text_right: float = col.get_center().x + text_w * 0.5
		assert_float(text_right).is_less(gear.position.x)
		assert_float(s.diorama.focus_point().y).is_greater(col.position.y)
		assert_float(s.diorama.focus_point().y).is_less(col.end.y)


func _collect_texts(n: Node, out: PackedStringArray) -> void:
	if n is Label and (n as Label).is_visible_in_tree():
		out.append((n as Label).text)
	if n is Button and (n as Button).is_visible_in_tree():
		out.append((n as Button).text)
	for c: Node in n.get_children():
		_collect_texts(c, out)
