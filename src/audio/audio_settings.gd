class_name AudioSettings
extends RefCounted
## Player audio options (settings UI and persistence arrive in M3/M4): music and SFX volume (0..1) and a mute
## switch. `apply()` writes them to the bus volumes; the UI bus follows the SFX volume.

const DEFAULT_MUSIC: float = 0.7
const DEFAULT_SFX: float = 1.0
## Volume at or below this (linear) counts as silent.
const SILENT: float = 0.001
const SILENT_DB: float = -80.0
## Debug arg: run silent (benches, captures). Honoured in every build; never saved.
const ARG_MUTE: String = "--mute"

var music_volume: float = DEFAULT_MUSIC
var sfx_volume: float = DEFAULT_SFX
var muted: bool = false
## Cinder's per-shot sounds: the shot tick (`sfx_laser_shot`) and its impact (`sfx_hit_metal` / `sfx_crit`); off
## silences both. Kills, alarms, UI and music are unaffected. Read live by `AudioEventRouter`.
var laser_sound: bool = true


static func is_mute_arg(args: PackedStringArray) -> bool:
	return args.has(ARG_MUTE)


static func linear_to_db_safe(v: float) -> float:
	if v <= SILENT:
		return SILENT_DB
	return linear_to_db(v)


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)


func to_dict() -> Dictionary:
	return {"music": music_volume, "sfx": sfx_volume, "muted": muted, "laser": laser_sound}


static func from_dict(d: Dictionary) -> AudioSettings:
	var s: AudioSettings = AudioSettings.new()
	s.set_music_volume(_number(d.get("music", DEFAULT_MUSIC), DEFAULT_MUSIC))
	s.set_sfx_volume(_number(d.get("sfx", DEFAULT_SFX), DEFAULT_SFX))
	var mu: Variant = d.get("muted", false)
	if mu is bool:
		var flag: bool = mu
		s.muted = flag
	var laser: Variant = d.get("laser", true)
	if laser is bool:
		var on: bool = laser
		s.laser_sound = on
	return s


static func _number(v: Variant, fallback: float) -> float:
	if v is float:
		var f: float = v
		return f
	if v is int:
		var i: int = v
		return float(i)
	return fallback


## Writes the volumes and mute to the AudioServer buses (missing buses are skipped).
func apply() -> void:
	_set_bus(AudioBuses.MUSIC, linear_to_db_safe(music_volume))
	_set_bus(AudioBuses.SFX, linear_to_db_safe(sfx_volume))
	_set_bus(AudioBuses.UI, linear_to_db_safe(sfx_volume))
	var master: int = AudioBuses.index_of(AudioBuses.MASTER)
	if master >= 0:
		AudioServer.set_bus_mute(master, muted)


func _set_bus(bus: StringName, volume_db: float) -> void:
	var idx: int = AudioBuses.index_of(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, volume_db)
