class_name TestResultsOverlay
extends GdUnitTestSuite

const SCENE_PATH: String = "res://src/ui/results_overlay.tscn"


func test_hidden_by_default_and_shows_fields_after_run() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	var overlay: ResultsOverlay = auto_free(packed.instantiate())
	add_child(overlay)
	assert_bool(overlay.visible).is_false()
	var c := RunController.new()
	c.start_run(1)
	c.fast_forward(60000)
	overlay.show_results(c.world)
	assert_bool(overlay.visible).is_true()
	var wave_label: Label = overlay.get_node("%WaveLabel")
	var cause_label: Label = overlay.get_node("%CauseLabel")
	assert_str(wave_label.text).is_equal("WAVE REACHED  %d" % c.world.run.death_wave)
	assert_str(cause_label.text).starts_with("CAUSE  ")


func test_redeploy_button_emits_signal() -> void:
	var packed: PackedScene = load(SCENE_PATH)
	var overlay: ResultsOverlay = auto_free(packed.instantiate())
	add_child(overlay)
	var hits: Array[int] = []
	overlay.redeploy_pressed.connect(func() -> void: hits.append(1))
	var button: Button = overlay.get_node("%RedeployButton")
	button.pressed.emit()
	assert_int(hits.size()).is_equal(1)
