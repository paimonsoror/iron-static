extends Control
## Host scene (M1-23, M3-14): BattleView, HUD, results overlay and debug overlay wired to `Game.controller`; the
## `ScreenRouter` owns which screen is up (menus, battle, results; see flow/screen_router.gd).
## Thin glue only: the state machine is RunController, ticking happens in Game._process (an autoload, so it
## runs before this node's _process each frame), this node renders and routes signals.

var _controller: RunController
## Pause the sim when the debug load wave is reached (static-crowd render bench, V1-03).
var _hold: bool = false
## Back gesture, app lifecycle and safe area (V1-24).
var _mobile: MobileShell
## Screen flow (M3-14): HOME / FOUNDRY / SETTINGS / SAVE_PROBLEM menus, BATTLE, RESULTS.
var _router: ScreenRouter
## Sim events -> sounds and adaptive music (A1-05, A1-07).
var _audio: AudioEventRouter

@onready var _battle: BattleView = %BattleView
@onready var _hud: Hud = %Hud
@onready var _results: ResultsOverlay = %ResultsOverlay
@onready var _debug: DebugOverlay = %DebugOverlay


func _ready() -> void:
	if Game.style_frame:
		get_tree().change_scene_to_file.call_deferred("res://src/debug/style_frame.tscn")
		return
	Log.info("boot ok")
	_controller = Game.controller
	_audio = AudioEventRouter.new(Game.audio)
	_hud.speed_changed.connect(_on_speed_changed)
	_hud.pause_toggled.connect(_on_pause_toggled)
	_hud.buy_requested.connect(Game.request_buy)
	_hud.field_rect_changed.connect(_battle.set_field_rect)  # Cinder centers in the open field (V1-25, V1-28)
	_results.redeploy_pressed.connect(_on_redeploy_pressed)
	_results.foundry_pressed.connect(_on_results_event.bind(AppFlow.Event.OPEN_FOUNDRY))
	_results.home_pressed.connect(_on_results_event.bind(AppFlow.Event.GO_HOME))
	_debug.band_forced.connect(_on_band_forced)
	_debug.load_requested.connect(_on_load_requested)
	_debug.best_wave_requested.connect(_on_best_wave_requested)
	_debug.scenario_requested.connect(_on_scenario_requested)
	_debug.run_requested.connect(_on_run_requested)
	_debug.layer_toggled.connect(_on_layer_toggled)
	_controller.load_finished.connect(_on_load_finished)
	_controller.run_started.connect(_on_run_started)
	_controller.run_ended.connect(_on_run_ended)
	_debug.setup(_controller)
	_debug.battle_view = _battle
	_debug.visual = Game.visual
	_hold = Game.debug_hold
	_router = ScreenRouter.new()
	add_child(_router)  # before MobileShell: the pause overlay stays topmost
	_router.setup(_controller, _battle, _hud, _results)
	_router.battle_entered.connect(_on_battle_entered)
	_mobile = MobileShell.new()
	add_child(_mobile)  # last child: its pause overlay is topmost
	_mobile.setup(_controller, _hud, _results, _debug)
	_mobile.set_router(_router)
	ShaderWarmup.start(self)
	_debug.force_perf = Game.perf_logging_forced()
	if Game.debug_load:
		Game.start_debug_load()
		_router.show_battle()
	else:
		_router.boot()
		_show_boot_notice()


@warning_ignore("unused_parameter")
func _process(delta: float) -> void:  # gdlint: ignore=unused-argument
	if _controller == null or _controller.world == null or AppFlow.is_menu(_router.current_screen()):
		return
	if _controller.load_wave == 0:
		_battle.set_speed_hint(_controller.speed)
		_battle.render(_controller.driver.acc / TickDriver.DT)
		_controller.time_scale = _battle.time_scale()  # slow-mo: view-only pacing for the next frame
		_audio.update()
	else:
		_audio.skip()  # debug load fast-forward: no sound for the unrendered ticks
	_hud.refresh(_controller.world, Time.get_ticks_msec() / 1000.0)


func _on_run_started(world: SimWorld) -> void:
	_results.hide_results()
	_battle.bind(world)
	_audio.bind(world)  # in-run music state and music start; a redeploy resets the cursor and the menu flag


func _on_run_ended(world: SimWorld) -> void:
	_audio.in_menu = true  # results screen: menu mix (the death sound still comes through update())
	_audio.play_results_tally(not Game.visual.reduce_motion)
	_results.show_results(world)


func _on_speed_changed(multiplier: int) -> void:
	_controller.speed = multiplier


func _on_pause_toggled(paused: bool) -> void:
	_controller.paused = paused


func _on_redeploy_pressed() -> void:
	@warning_ignore("return_value_discarded")  # the router starts the run (Game.start_run) on its DEPLOY path
	_router.dispatch(AppFlow.Event.DEPLOY)


## Results FOUNDRY and HOME buttons (M3-17): the router applies the flow event.
func _on_results_event(event: AppFlow.Event) -> void:
	@warning_ignore("return_value_discarded")
	_router.dispatch(event)


## A resumed run starts paused: show the PAUSED overlay (V1-24 style) behind which the player taps to continue,
## with the pending notice ("RUN RESTORED") on it.
func _on_battle_entered() -> void:
	if _controller.paused:
		_mobile.pause()
		var text: String = _router.take_notice()
		if text != "":
			_mobile.overlay().set_notice(text)


## `Game.notice` once, as a toast on the boot screen. A paused boot battle already put it on the overlay; with a
## run waiting behind the title's CONTINUE, "RUN RESTORED" waits for that battle instead.
func _show_boot_notice() -> void:
	if _router.current_screen() == AppFlow.Screen.BATTLE:
		return
	if Game.has_pending_resume() and Game.notice == "save.resumed":
		return
	@warning_ignore("return_value_discarded")
	_router.show_notice_toast()


func _on_band_forced(band: int) -> void:
	_battle.band_override = band


func _on_load_requested() -> void:
	_debug.force_perf = true
	_hold = false
	Game.start_debug_load(RunController.LOAD_WAVE)


func _on_scenario_requested(wave: int, hold: bool) -> void:
	_debug.force_perf = true
	_hold = hold
	Log.info("[BENCH] scenario start wave=%d hold=%d tier=%s" % [wave, int(hold), Game.visual.quality.tier_name()])
	Game.start_debug_load(wave)


func _on_layer_toggled(layer: int) -> void:
	var node: CanvasItem = _battle if layer == DebugOverlay.LAYER_BATTLEFIELD else _hud
	node.visible = not node.visible
	Log.info("[BENCH] layer=%d visible=%d" % [layer, int(node.visible)])


func _on_run_requested() -> void:
	_hold = false
	_controller.paused = false


func _on_load_finished(world: SimWorld) -> void:
	if _hold:
		_controller.paused = true
	Log.info("[BENCH] load finished wave=%d enemies=%d hold=%d" % [world.wave, world.enemies.alive_count, int(_hold)])


func _on_best_wave_requested(wave: int) -> void:
	Game.best_wave_s1 = wave
