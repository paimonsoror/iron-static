class_name SettingsApplier
extends RefCounted
## Writes `PlayerSettings` into the runtime objects (audio buses, visual options, number format) and reads
## the persisted meaning back (M3-10). Session args (`--mute`, `--shake=`, `--quality=`, `--debug-novsync`)
## are applied last and flagged in `session_override`; `capture()` never saves them, it reports the persisted
## value instead. The settings screen should call `release_override(key)` when the player edits that control.

const KEY_MUTED: String = "muted"
const KEY_SHAKE: String = "shake"
const KEY_QUALITY: String = "quality"
const KEY_FPS_CAP: String = "fps_cap"
## Bench flag (also read by `Game`): engine cap 0, never saved.
const ARG_NOVSYNC: String = "--debug-novsync"

## key -> true for every setting currently forced by a session arg.
var session_override: Dictionary = {}
var _persisted: PlayerSettings = PlayerSettings.new()


## Applies `settings` to the runtime objects, then lets the session args win (not saved).
func apply(
	settings: PlayerSettings, game_visual: VisualSettings, game_audio: AudioSettings, args: PackedStringArray
) -> void:
	_persisted = PlayerSettings.from_dict(settings.to_dict())
	session_override.clear()
	game_audio.set_music_volume(settings.music)
	game_audio.set_sfx_volume(settings.sfx)
	game_audio.muted = settings.muted
	game_visual.reduce_motion = settings.reduce_motion
	game_visual.screen_shake = VisualSettings.parse_shake(settings.shake)
	game_visual.scanline_intensity = settings.scanline_intensity()
	game_visual.fps_cap = VisualSettings.snap_fps_cap(settings.fps_cap)
	NumberFormat.style = settings.number_format_style()
	_apply_session_args(game_visual, game_audio, args)
	game_audio.apply()
	game_visual.apply_fps_cap()


## Reads the persisted-meaning values back from the runtime objects (session overrides excluded).
func capture(game_visual: VisualSettings, game_audio: AudioSettings) -> PlayerSettings:
	var s: PlayerSettings = PlayerSettings.from_dict(_persisted.to_dict())
	s.music = game_audio.music_volume
	s.sfx = game_audio.sfx_volume
	s.reduce_motion = game_visual.reduce_motion
	s.scanlines = PlayerSettings.scanline_level_for(game_visual.scanline_intensity)
	s.number_format = NumberFormat.STYLE_NAMES[clampi(NumberFormat.style, 0, 2)]
	if not session_override.has(KEY_MUTED):
		s.muted = game_audio.muted
	if not session_override.has(KEY_SHAKE):
		s.shake = VisualSettings.SHAKE_NAMES[game_visual.screen_shake]
	if not session_override.has(KEY_FPS_CAP):
		s.fps_cap = game_visual.fps_cap if game_visual.fps_cap > 0 else _persisted.fps_cap
	return s


## The player changed this control: it is no longer forced by a session arg and the new value is persisted.
func release_override(key: String) -> void:
	session_override.erase(key)


func is_overridden(key: String) -> bool:
	return session_override.has(key)


func _apply_session_args(game_visual: VisualSettings, game_audio: AudioSettings, args: PackedStringArray) -> void:
	if AudioSettings.is_mute_arg(args):
		game_audio.muted = true
		session_override[KEY_MUTED] = true
	for a: String in args:
		if a.begins_with(VisualSettings.ARG_SHAKE):
			game_visual.screen_shake = VisualSettings.parse_shake(a.substr(VisualSettings.ARG_SHAKE.length()))
			session_override[KEY_SHAKE] = true
		elif a.begins_with(VisualQuality.ARG_QUALITY):
			game_visual.set_tier(VisualQuality.tier_from_args(args))
			session_override[KEY_QUALITY] = true
		elif a == ARG_NOVSYNC:
			game_visual.fps_cap = 0
			session_override[KEY_FPS_CAP] = true
