extends Control
## Host scene (M1-23): BattleView, HUD, results overlay and debug overlay wired to `Game.controller`.
## Thin glue only: the state machine is RunController, ticking happens in Game._process (an autoload, so it
## runs before this node's _process each frame), this node renders and routes signals.

var _controller: RunController

@onready var _battle: BattleView = %BattleView
@onready var _hud: Hud = %Hud
@onready var _results: ResultsOverlay = %ResultsOverlay
@onready var _debug: DebugOverlay = %DebugOverlay


func _ready() -> void:
	Log.info("boot ok")
	_controller = Game.controller
	_hud.speed_changed.connect(_on_speed_changed)
	_hud.pause_toggled.connect(_on_pause_toggled)
	_results.redeploy_pressed.connect(_on_redeploy_pressed)
	_debug.band_forced.connect(_on_band_forced)
	_debug.load_requested.connect(_on_load_requested)
	_controller.run_started.connect(_on_run_started)
	_controller.run_ended.connect(_on_run_ended)
	_debug.setup(_controller)
	_debug.battle_view = _battle
	_debug.force_perf = Game.perf_logging_forced()
	if Game.debug_load:
		Game.start_debug_load()
	else:
		Game.start_run(RunController.DEFAULT_SEED)


@warning_ignore("unused_parameter")
func _process(delta: float) -> void:  # gdlint: ignore=unused-argument
	if _controller.world == null:
		return
	if _controller.load_wave == 0:
		_battle.render(_controller.driver.acc / TickDriver.DT)
	_hud.refresh(_controller.world, Time.get_ticks_msec() / 1000.0)


func _on_run_started(world: SimWorld) -> void:
	_results.hide_results()
	_battle.bind(world)


func _on_run_ended(world: SimWorld) -> void:
	_results.show_results(world)


func _on_speed_changed(multiplier: int) -> void:
	_controller.speed = multiplier


func _on_pause_toggled(paused: bool) -> void:
	_controller.paused = paused


func _on_redeploy_pressed() -> void:
	Game.redeploy()


func _on_band_forced(band: int) -> void:
	_battle.band_override = band


func _on_load_requested() -> void:
	_debug.force_perf = true
	Game.start_debug_load()
