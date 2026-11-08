class_name MusicDirector
extends Node
## Adaptive music: one AudioStreamSynchronized holds the equal-length layer loops (pad, pulse, perc, lead), so
## they stay sample-locked; each layer's volume follows the MusicIntensity targets with a linear fade.
## Wiring (phase 2) calls `set_state`; nothing here reads the sim.

var model: MusicIntensity = MusicIntensity.new()
var state: MusicState = MusicState.new()

var _player: AudioStreamPlayer = null
var _sync: AudioStreamSynchronized = null
var _levels: PackedFloat32Array = PackedFloat32Array()
var _targets: PackedFloat32Array = PackedFloat32Array()
var _slot_db: PackedFloat32Array = PackedFloat32Array()
var _started: bool = false
var _setup_done: bool = false


## `setup()` once (a failed setup is not retried, so its error is logged a single time).
func ensure_setup() -> void:
	if not _setup_done:
		setup()


## Loads the layer rules and the layer streams (a missing file leaves that layer silent and logs an error).
func setup() -> void:
	_setup_done = true
	model = MusicIntensity.load_default()
	if not model.error.is_empty():
		push_error("MusicDirector: " + model.error)
		return
	_sync = AudioStreamSynchronized.new()
	_sync.stream_count = model.rules.size()
	for i: int in range(model.rules.size()):
		var layer: String = model.rules[i].layer
		var s: AudioStream = AudioSlots.stream(layer)
		if s is AudioStreamOggVorbis:
			var ogg: AudioStreamOggVorbis = s
			ogg.loop = true
		_sync.set_sync_stream(i, s)
		@warning_ignore("return_value_discarded")
		_slot_db.append(AudioSlots.slot(layer).volume_db)
		@warning_ignore("return_value_discarded")
		_levels.append(0.0)
	_player = AudioStreamPlayer.new()
	_player.bus = AudioBuses.MUSIC
	_player.stream = _sync
	add_child(_player)


func is_started() -> bool:
	return _started


## Starts all layers together; levels jump to the current targets.
func start() -> void:
	if _player == null or _started:
		return
	_started = true
	_targets = model.targets(state)
	_levels = _targets.duplicate()
	_apply_levels()
	_player.play()


func stop() -> void:
	if _player != null:
		_player.stop()
	_started = false


func set_state(s: MusicState) -> void:
	state = s
	if _started:
		_targets = model.targets(state)


func pause() -> void:
	if _player != null:
		_player.stream_paused = true


func resume() -> void:
	if _player != null:
		_player.stream_paused = false


## Current linear level of layer `i` (for debug overlays and tests).
func level(i: int) -> float:
	return _levels[i] if i >= 0 and i < _levels.size() else 0.0


func _process(delta: float) -> void:
	if not _started:
		return
	for i: int in range(_levels.size()):
		var rule: MusicLayerRule = model.rules[i]
		_levels[i] = MusicIntensity.step(_levels[i], _targets[i], delta, rule.fade_in_s, rule.fade_out_s)
	_apply_levels()


func _apply_levels() -> void:
	for i: int in range(_levels.size()):
		_sync.set_sync_stream_volume(i, _slot_db[i] + AudioSettings.linear_to_db_safe(_levels[i]))
