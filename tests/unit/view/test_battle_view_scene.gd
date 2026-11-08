class_name TestBattleViewScene
extends GdUnitTestSuite
## Headless instantiation of battle_view.tscn and hud.tscn bound to a real SimWorld.


func test_battle_view_binds_steps_and_renders() -> void:
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	var scene: PackedScene = load("res://src/view/battle_view.tscn")
	var view: BattleView = auto_free(scene.instantiate())
	add_child(view)
	view.layout(Vector2(1080.0, 1920.0))
	view.bind(world)
	for i: int in 200:
		world.step()
		if i % 10 == 0:
			view.render(0.5)
	view.render(1.0)
	assert_float(view.px_per_m()).is_equal_approx(1080.0 / 38.0, 0.001)
	assert_vector(view.position).is_equal(Vector2(540.0, 537.6))
	view.layout(Vector2(1080.0, 2400.0))
	view.render(0.0)
	assert_vector(view.position).is_equal(Vector2(540.0, 672.0))


func test_hud_shows_values_and_emits_signals() -> void:
	var world := SimWorld.new(SimConfigLoader.load_default(1))
	var scene: PackedScene = load("res://src/ui/hud.tscn")
	var hud: Hud = auto_free(scene.instantiate())
	add_child(hud)
	for i: int in 30:
		world.step()
	hud.refresh(world, 0.0)
	hud.show_values(7, 360, 50.0, 100.0, BigNum.from_float(12400.0), BigNum.from_float(3.0))
	var wave_label: Label = hud.get_node("%WaveLabel")
	var hp_label: Label = hud.get_node("%HpLabel")
	var scrap_label: Label = hud.get_node("%ScrapLabel")
	var data_label: Label = hud.get_node("%DataLabel")
	var timer_bar: ProgressBar = hud.get_node("%TimerBar")
	assert_str(wave_label.text).is_equal("WAVE 7")
	assert_str(hp_label.text).is_equal("50 / 100")
	assert_str(scrap_label.text).is_equal("SCRAP 12.4K")
	assert_str(data_label.text).is_equal("DATA 3")
	assert_float(timer_bar.value).is_equal(360.0)
	assert_object(hud.upgrade_panel()).is_not_null()
	var speeds: Array[int] = []
	var pauses: Array[bool] = []
	hud.speed_changed.connect(func(m: int) -> void: speeds.append(m))
	hud.pause_toggled.connect(func(p: bool) -> void: pauses.append(p))
	var speed_button: Button = hud.get_node("%SpeedButton")
	var pause_button: Button = hud.get_node("%PauseButton")
	speed_button.pressed.emit()
	speed_button.pressed.emit()
	pause_button.pressed.emit()
	assert_array(speeds).is_equal([2, 1])
	assert_array(pauses).is_equal([true])
	assert_bool(hud.is_paused()).is_true()
	assert_float(speed_button.size.y).is_greater_equal(56.0)
	assert_float(pause_button.size.y).is_greater_equal(56.0)
