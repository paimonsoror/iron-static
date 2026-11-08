class_name AmbienceDirector
extends Node
## Title and Home ambience (M3-31, design 11 s4): the seamless wind and metal-creak loops, played together on the
## SFX bus (slot rows `amb_*` of `assets/audio/slots.csv`) and faded in and out as one. The two loops have different
## lengths (36 s and 52 s), so their combination does not audibly repeat. Presentation only; owned by AudioDirector.

const LAYERS: Array[String] = ["amb_wasteland_wind", "amb_metal_creak"]
const FADE_IN_S: float = 4.0
const FADE_OUT_S: float = 2.5

var _players: Array[AudioStreamPlayer] = []
var _slot_db: PackedFloat32Array = PackedFloat32Array()
var _level: float = 0.0
var _target: float = 0.0
var _playing: bool = false
var _setup_done: bool = false


## `setup()` once (a failed setup is not retried, so its error is logged a single time).
func ensure_setup() -> void:
	if not _setup_done:
		setup()


## Builds one looping player per layer (a missing file leaves that layer out and logs an error).
func setup() -> void:
	_setup_done = true
	for layer: String in LAYERS:
		var s: AudioStream = AudioSlots.stream(layer)
		if s == null:
			continue
		if s is AudioStreamOggVorbis:
			var ogg: AudioStreamOggVorbis = s
			ogg.loop = true
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = AudioSlots.slot(layer).bus
		p.stream = s
		p.volume_db = AudioSettings.SILENT_DB
		add_child(p)
		_players.append(p)
		@warning_ignore("return_value_discarded")
		_slot_db.append(AudioSlots.slot(layer).volume_db)


## Fades the ambience in (starts the loops on the first call). Idempotent.
func start() -> void:
	ensure_setup()
	_target = 1.0
	if _playing or _players.is_empty():
		return
	_playing = true
	_level = 0.0
	_apply_levels()
	for p: AudioStreamPlayer in _players:
		p.play()


## Fades the ambience out; the loops stop when the fade ends.
func stop() -> void:
	_target = 0.0


## Silences the ambience at once (shutdown, `--mute`).
func stop_now() -> void:
	_target = 0.0
	_level = 0.0
	_halt()


## True between `start()` and `stop()` (the fade-out tail still sounds but the ambience is no longer wanted).
func is_active() -> bool:
	return _target > 0.0


## True while any loop is playing (including a fade-out tail).
func is_playing() -> bool:
	return _playing


## Current linear fade level 0..1 (debug and tests).
func level() -> float:
	return _level


func pause() -> void:
	for p: AudioStreamPlayer in _players:
		p.stream_paused = true


func resume() -> void:
	for p: AudioStreamPlayer in _players:
		p.stream_paused = false


## Stops playback and releases the streams on shutdown (no playback may hold a stream at engine exit).
func _exit_tree() -> void:
	_halt()
	for p: AudioStreamPlayer in _players:
		p.stream = null


func _process(delta: float) -> void:
	if not _playing:
		return
	_level = MusicIntensity.step(_level, _target, delta, FADE_IN_S, FADE_OUT_S)
	if _level <= 0.0 and _target <= 0.0:
		_halt()
		return
	_apply_levels()


func _halt() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
	_playing = false


func _apply_levels() -> void:
	var fade_db: float = AudioSettings.linear_to_db_safe(_level)
	for i: int in range(_players.size()):
		_players[i].volume_db = _slot_db[i] + fade_db
