class_name SpyAudioDirector
extends AudioDirector
## Test double: records every call instead of playing (no buses, no streams, no players).

var sfx: Array[String] = []
var jitters: Array[float] = []
var semitone_log: Array[float] = []
var buy_steps: int = 0
var buy_ends: int = 0
var pauses: int = 0
var resumes: int = 0
var music_starts: int = 0
var states: Array[MusicState] = []
var menu_audio_starts: int = 0
var menu_audio_stops: int = 0
## Order of the calls, e.g. ["pause", "sfx_ui_tap"].
var log: Array[String] = []


func play_sfx(sfx_id: String, pitch_jitter: float = -1.0, semitones: float = 0.0) -> bool:
	sfx.append(sfx_id)
	jitters.append(pitch_jitter)
	semitone_log.append(semitones)
	log.append(sfx_id)
	return true


func play_buy_step() -> bool:
	buy_steps += 1
	log.append("buy_step")
	return true


func end_buy_hold() -> void:
	buy_ends += 1
	log.append("buy_end")


func pause_all() -> void:
	pauses += 1
	log.append("pause")


func resume_all() -> void:
	resumes += 1
	log.append("resume")


func start_music() -> void:
	music_starts += 1


func set_music_state(state: MusicState) -> void:
	states.append(state)


func start_menu_audio() -> void:
	menu_audio_starts += 1
	log.append("menu_audio_start")


func stop_menu_audio() -> void:
	menu_audio_stops += 1
	log.append("menu_audio_stop")


func is_menu_ambience_active() -> bool:
	return menu_audio_starts > menu_audio_stops


func count(sfx_id: String) -> int:
	return sfx.count(sfx_id)
