class_name TestFtueOverlay
extends GdUnitTestSuite
## FtueOverlay, FtuePointer and FtueWatcher (M4-26): taps pass through, the pointer lands on the script row, reduce
## motion removes the bob, SKIP HINTS persists, events from the sim start and end beats.

var _persisted: int = 0


func _world() -> SimWorld:
	return SimWorld.new(SimConfigLoader.load_default(1))


func _profile(runs_total: int = 0) -> PlayerProfile:
	var p: PlayerProfile = PlayerProfile.fresh(0, "t")
	p.runs_total = runs_total
	return p


func _count() -> void:
	_persisted += 1


## A 1080x2400 root with an upgrade panel (bound to `world`) and the overlay wired to it, BATTLE on screen.
func _rig(world: SimWorld, runs_total: int = 0) -> Array:
	var root: Control = auto_free(Control.new())
	root.size = Vector2(1080.0, 2400.0)
	add_child(root)
	var panel: UpgradePanel = (load("res://src/ui/upgrade_panel.tscn") as PackedScene).instantiate()
	root.add_child(panel)
	panel.max_height_px = 900.0
	panel.bind(world)
	var overlay := FtueOverlay.new()
	overlay.reduce_motion = true
	root.add_child(overlay)
	overlay.target_resolver = func(target: String) -> Rect2: return FtueTargets.resolve(target, panel, null, null)
	overlay.persist = func() -> void: _persisted += 1
	overlay.set_screen(AppFlow.Screen.BATTLE)
	overlay.start_run(world, _profile(runs_total))
	return [overlay, panel]


func test_overlay_ignores_input_but_the_skip_button_takes_touches() -> void:
	var rig: Array = _rig(_world())
	var overlay: FtueOverlay = rig[0]
	assert_int(overlay.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(overlay.pointer().mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_int(overlay.skip_button().mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	assert_bool(overlay.skip_button().size.y >= 148.0 or overlay.skip_button().custom_minimum_size.y >= 148.0).is_true()


func test_pointer_rect_equals_the_laser_output_row_rect() -> void:
	var rig: Array = _rig(_world())
	var overlay: FtueOverlay = rig[0]
	var panel: UpgradePanel = rig[1]
	await get_tree().process_frame
	await get_tree().process_frame
	overlay.set_screen(AppFlow.Screen.BATTLE)
	var row: Rect2 = panel.row_rect("laser_output")
	assert_float(row.size.x).is_greater(0.0)
	assert_bool(overlay.is_hint_visible()).is_true()
	assert_str(overlay.label_text()).is_equal("UPGRADE")
	assert_bool(overlay.pointer().has_target()).is_true()
	assert_object(overlay.pointer().target_rect()).is_equal(Rect2(row.position - overlay.global_position, row.size))


func test_pointer_falls_back_to_the_tab_when_the_row_is_on_another_tab() -> void:
	var rig: Array = _rig(_world())
	var panel: UpgradePanel = rig[1]
	await get_tree().process_frame
	assert_bool(panel.set_tab("chassis")).is_true()
	await get_tree().process_frame
	assert_float(panel.row_rect("laser_output").size.x).is_equal(0.0)
	assert_object(panel.pointer_rect("laser_output")).is_equal(panel.tab_rect("laser_output"))
	assert_float(panel.tab_rect("laser_output").size.x).is_greater(0.0)
	assert_object(panel.pointer_rect("no_such_row")).is_equal(Rect2())


func test_reduce_motion_replaces_the_bob_with_a_static_marker() -> void:
	assert_float(FtuePointer.bob_offset(0.1, true)).is_equal(0.0)
	assert_float(FtuePointer.bob_offset(0.1, false)).is_greater(0.0)
	assert_float(FtuePointer.outline_alpha(0.3, true)).is_equal(1.0)
	assert_float(FtuePointer.outline_alpha(0.0, false)).is_less(1.0)
	var rig: Array = _rig(_world())
	var overlay: FtueOverlay = rig[0]
	await get_tree().process_frame
	var pointer: FtuePointer = overlay.pointer()
	assert_bool(pointer.has_target()).is_true()  # the static marker is still drawn
	assert_bool(pointer.is_animated()).is_false()
	assert_bool(pointer.is_processing()).is_false()
	overlay.reduce_motion = false
	pointer.reduce_motion = false
	pointer.point_at(Rect2(100.0, 1500.0, 800.0, 180.0), true)
	assert_bool(pointer.is_animated()).is_true()
	assert_bool(pointer.is_processing()).is_true()


func test_a_beat_shows_only_on_its_own_screen() -> void:
	assert_bool(FtueOverlay.shown_on("row:laser_output", AppFlow.Screen.BATTLE)).is_true()
	assert_bool(FtueOverlay.shown_on("row:laser_output", AppFlow.Screen.RESULTS)).is_false()
	assert_bool(FtueOverlay.shown_on("field", AppFlow.Screen.BATTLE)).is_true()
	assert_bool(FtueOverlay.shown_on("results_foundry", AppFlow.Screen.RESULTS)).is_true()
	assert_bool(FtueOverlay.shown_on("results_foundry", AppFlow.Screen.BATTLE)).is_false()
	assert_bool(FtueOverlay.shown_on("foundry_row:laser_output", AppFlow.Screen.FOUNDRY)).is_true()
	assert_bool(FtueOverlay.shown_on("none", AppFlow.Screen.BATTLE)).is_false()
	var rig: Array = _rig(_world())
	var overlay: FtueOverlay = rig[0]
	overlay.set_screen(AppFlow.Screen.HOME)
	assert_bool(overlay.is_hint_visible()).is_false()
	overlay.set_screen(AppFlow.Screen.BATTLE)
	assert_bool(overlay.is_hint_visible()).is_true()


func test_skip_hints_ends_every_beat_and_persists() -> void:
	_persisted = 0
	var rig: Array = _rig(_world())
	var overlay: FtueOverlay = rig[0]
	assert_bool(overlay.is_hint_visible()).is_true()
	overlay.skip_button().pressed.emit()
	assert_bool(overlay.is_hint_visible()).is_false()
	assert_bool(overlay.state.skipped).is_true()
	assert_bool(overlay.pointer().has_target()).is_false()
	assert_int(_persisted).is_greater(0)  # the overlay's own persist lambda counted it


func test_a_profile_past_run_two_shows_nothing() -> void:
	var rig: Array = _rig(_world(), 2)
	var overlay: FtueOverlay = rig[0]
	assert_bool(overlay.is_hint_visible()).is_false()
	assert_bool(overlay.state.enabled()).is_false()


func test_watcher_turns_sim_events_into_beats() -> void:
	var w: SimWorld = _world()
	var state: FtueState = FtueState.load_from(FtueScript.load_default(), _profile())
	@warning_ignore("return_value_discarded")
	state.begin_run(0)
	var watcher := FtueWatcher.new()
	watcher.bind(w)
	var dart: int = -1
	for i: int in w.config.enemies.size():
		if w.config.enemies[i].id == "dart":
			dart = i
	w.events.push(SimEventKind.ENEMY_KILLED, 0, 0)
	w.events.push(SimEventKind.ENEMY_SPAWNED, 3, dart)
	w.events.push(SimEventKind.CINDER_HIT, 5, 0)
	w.events.push(SimEventKind.DRAFT_OPENED, 10, 3)
	watcher.update(state)
	assert_bool(state.is_done("first_kill")).is_true()
	assert_bool(state.is_done("draft_note")).is_true()
	assert_bool(watcher.has_fired(FtueScript.DART_FIRST_SEEN)).is_true()
	assert_bool(watcher.has_fired(FtueScript.FIRST_DAMAGE_TAKEN)).is_true()
	# upgrade_laser is active (run1_start); dart and the hull beats queued behind it
	assert_str(state.active().id).is_equal("upgrade_laser")
	assert_int(state.queued_count()).is_equal(3)
	w.events.push(SimEventKind.UPGRADE_BOUGHT, 0, 1)  # row 0 is laser_output
	watcher.update(state)
	assert_str(state.active().id).is_equal("dart_label")
	w.events.push(SimEventKind.RUN_ENDED, 7, 0)
	watcher.update(state)
	assert_bool(state.is_done("death_note")).is_true()


func test_scrap_affords_cycle_rate_needs_a_kill_first() -> void:
	var w: SimWorld = _world()
	var state: FtueState = FtueState.load_from(FtueScript.load_default(), _profile())
	var watcher := FtueWatcher.new()
	watcher.bind(w)
	for i: int in FtueWatcher.CHECK_EVERY * 2:
		watcher.update(state)
	assert_bool(watcher.has_fired(FtueScript.SCRAP_AFFORDS_CYCLE_RATE)).is_false()
	w.events.push(SimEventKind.ENEMY_KILLED, 0, 0)
	w.economy.scrap = BigNum.from_int(100000)
	for i: int in FtueWatcher.CHECK_EVERY:
		watcher.update(state)
	assert_bool(watcher.has_fired(FtueScript.SCRAP_AFFORDS_CYCLE_RATE)).is_true()
	assert_str(state.active().id).is_equal("upgrade_rate")


func test_results_and_foundry_beats_pulse_and_hand_over() -> void:
	var rig: Array = _rig(_world(), 0)
	var overlay: FtueOverlay = rig[0]
	assert_str(overlay.state.active().id).is_equal("upgrade_laser")  # still up when the run ends
	overlay.set_screen(AppFlow.Screen.RESULTS)
	overlay.on_results_shown()
	assert_str(overlay.state.active().id).is_equal("results_foundry")
	assert_bool(overlay.foundry_pulse_wanted()).is_true()
	overlay.set_screen(AppFlow.Screen.FOUNDRY)
	overlay.on_foundry_opened()
	assert_bool(overlay.state.is_done("results_foundry")).is_true()
	assert_bool(overlay.foundry_pulse_wanted()).is_false()
	assert_str(overlay.state.active().id).is_equal("foundry_hold")
