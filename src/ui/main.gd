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
## Sim events -> haptic pulses (M4-22).
var _haptic_hooks: HapticHooks
## Patch draft overlay (M4-16): opened while the sim has a draft open, closed by a pick or a run ending behind it.
var _draft: DraftOverlay
## Tier-up banner (VT-5): "LASER MK II" below the HUD bar; started by the battle view's tier_banner_requested.
var _tier_banner: TierBanner

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
	_haptic_hooks = HapticHooks.new(Game.haptics)
	_controller.auto_pick_draft = false  # the player picks (the stopgap stays on for headless runs and the debug load)
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
	_draft = (load("res://src/ui/draft/draft_overlay.tscn") as PackedScene).instantiate() as DraftOverlay
	add_child(_draft)  # above the router screens, below the pause overlay (back opens the pause menu over a draft)
	_draft.picked.connect(_on_draft_picked)
	_tier_banner = TierBanner.new()
	add_child(_tier_banner)  # above the draft overlay, below the pause overlay
	_battle.tier_banner_requested.connect(_tier_banner.play_moment)
	_hud.field_rect_changed.connect(_tier_banner.set_field_rect)
	_mobile = MobileShell.new()
	add_child(_mobile)  # last child: its pause overlay is topmost
	_mobile.setup(_controller, _hud, _results, _debug)
	_mobile.set_router(_router)
	_mobile.saves = Game.saves
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
	_sync_draft()
	if _controller == null or _controller.world == null or AppFlow.is_menu(_router.current_screen()):
		return
	if _controller.load_wave == 0:
		_battle.set_speed_hint(_controller.speed)
		_battle.render(_controller.driver.acc / TickDriver.DT)
		_controller.time_scale = _battle.time_scale()  # slow-mo: view-only pacing for the next frame
		_audio.update()
		_haptic_hooks.update()
	else:
		_audio.skip()  # debug load fast-forward: no sound for the unrendered ticks
		_haptic_hooks.skip()
		_battle.skip_tier_ups()
	_hud.refresh(_controller.world, Time.get_ticks_msec() / 1000.0)


func _on_run_started(world: SimWorld) -> void:
	_results.hide_results()
	_tier_banner.cancel()
	_battle.bind(world)
	_haptic_hooks.bind(world)
	_audio.bind(world)  # in-run music state and music start; a redeploy resets the cursor and the menu flag


func _on_run_ended(world: SimWorld) -> void:
	_tier_banner.cancel()
	_audio.in_menu = true  # results screen: menu mix (the death sound still comes through update())
	_audio.play_results_tally(not Game.visual.reduce_motion)
	_results.show_results(world)


func _on_speed_changed(multiplier: int) -> void:
	_controller.speed = multiplier


## The HUD pause button opens the pause menu (it covers the HUD, so it can only toggle on here; off is a safety net).
func _on_pause_toggled(paused: bool) -> void:
	if paused:
		_mobile.pause()
	else:
		_mobile.resume()


func _on_redeploy_pressed() -> void:
	@warning_ignore("return_value_discarded")  # the router starts the run (Game.start_run) on its DEPLOY path
	_router.dispatch(AppFlow.Event.DEPLOY)


## Results FOUNDRY and HOME buttons (M3-17): the router applies the flow event.
func _on_results_event(event: AppFlow.Event) -> void:
	@warning_ignore("return_value_discarded")
	_router.dispatch(event)


## A resumed run starts paused: show the pause menu (RESUME / ABORT MISSION / EXIT GAME) with the pending notice
## ("RUN RESTORED") on it.
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


## Opens the draft overlay while the battle has an open patch draft (also after a snapshot restore or a return from the
## background: the state, not an event, decides) and closes it when the draft is gone or the battle is not on screen
## (abort, run end). While it is open the HUD shows the paused state: the sim does not step behind a draft.
func _sync_draft() -> void:
	if _controller == null or _draft == null:
		return
	var w: SimWorld = _controller.world
	var wanted: bool = (
		w != null
		and _controller.state == RunController.State.IN_RUN
		and _controller.load_wave == 0
		and not AppFlow.is_menu(_router.current_screen())
		and w.is_draft_open()
	)
	if wanted and not _draft.is_open():
		_draft.open(w)
	elif not wanted and _draft.is_open():
		_draft.close()
	if wanted and not _hud.is_paused():
		_hud.set_paused(true)


func _on_draft_picked(_slot: int) -> void:
	_haptic_hooks.draft_pick()
	_hud.set_paused(_controller.paused)
