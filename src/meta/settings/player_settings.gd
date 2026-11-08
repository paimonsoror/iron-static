class_name PlayerSettings
extends RefCounted
## Persisted player settings, v1 (M3-10). Stored in `PlayerProfile.settings` as the `to_dict` shape.
## All keys are optional on read, clamped, unknown keys kept in `extra`. Not in v1: quality tier (arg/auto),
## haptics, left-handed, colorblind, high contrast (M4).

const LEVEL_NAMES: Array[String] = ["off", "low", "normal"]
## Scanline opacity per level name (Q44).
const SCANLINE_VALUES: Array[float] = [0.0, 0.03, 0.06]
const DEFAULT_SHAKE: String = "low"
const DEFAULT_SCANLINES: String = "normal"
const DEFAULT_NUMBER_FORMAT: String = "short"
const DEFAULT_FPS_CAP: int = 60
const KNOWN_KEYS: Array[String] = [
	"music", "sfx", "muted", "reduce_motion", "shake", "scanlines", "number_format", "fps_cap"
]

var music: float = AudioSettings.DEFAULT_MUSIC
## Labelled "Sound" in the UI.
var sfx: float = AudioSettings.DEFAULT_SFX
var muted: bool = false
var reduce_motion: bool = false
var shake: String = DEFAULT_SHAKE
var scanlines: String = DEFAULT_SCANLINES
var number_format: String = DEFAULT_NUMBER_FORMAT
var fps_cap: int = DEFAULT_FPS_CAP
var extra: Dictionary = {}


## Scanline opacity for the current level name.
func scanline_intensity() -> float:
	return SCANLINE_VALUES[maxi(LEVEL_NAMES.find(scanlines), 0)]


## Level name for a scanline opacity (nearest; used when capturing runtime values).
static func scanline_level_for(intensity: float) -> String:
	var best: int = 0
	for i: int in SCANLINE_VALUES.size():
		if absf(SCANLINE_VALUES[i] - intensity) < absf(SCANLINE_VALUES[best] - intensity):
			best = i
	return LEVEL_NAMES[best]


func to_dict() -> Dictionary:
	var d: Dictionary = extra.duplicate(true)
	var audio: AudioSettings = AudioSettings.new()
	audio.set_music_volume(music)
	audio.set_sfx_volume(sfx)
	audio.muted = muted
	d.merge(audio.to_dict(), true)
	d["reduce_motion"] = reduce_motion
	d["shake"] = shake
	d["scanlines"] = scanlines
	d["number_format"] = number_format
	d["fps_cap"] = fps_cap
	return d


static func from_dict(d: Dictionary) -> PlayerSettings:
	var s: PlayerSettings = PlayerSettings.new()
	var audio: AudioSettings = AudioSettings.from_dict(d)
	s.music = audio.music_volume
	s.sfx = audio.sfx_volume
	s.muted = audio.muted
	var rm: Variant = d.get("reduce_motion", false)
	if rm is bool:
		var flag: bool = rm
		s.reduce_motion = flag
	s.shake = _pick(d.get("shake", null), LEVEL_NAMES, DEFAULT_SHAKE)
	s.scanlines = _pick(d.get("scanlines", null), LEVEL_NAMES, DEFAULT_SCANLINES)
	s.number_format = _pick(d.get("number_format", null), NumberFormat.STYLE_NAMES, DEFAULT_NUMBER_FORMAT)
	s.fps_cap = _read_fps_cap(d.get("fps_cap", null))
	for key: Variant in d.keys():
		if not (key is String and KNOWN_KEYS.has(key)):
			s.extra[key] = d[key]
	return s


## NumberFormat style id (NumberFormat.SHORT / SCIENTIFIC / ENGINEERING).
func number_format_style() -> int:
	return maxi(NumberFormat.STYLE_NAMES.find(number_format), 0)


static func _pick(raw: Variant, allowed: Array[String], fallback: String) -> String:
	if raw is String:
		var text: String = raw
		var norm: String = text.strip_edges().to_lower()
		if allowed.has(norm):
			return norm
	return fallback


## 30 or 60 (anything else snaps to the nearest offered cap); 0, negatives and non-numbers fall back to 60
## (0 means uncapped and is bench-only).
static func _read_fps_cap(raw: Variant) -> int:
	var n: int = 0
	if raw is int:
		var i: int = raw
		n = i
	elif raw is float:
		var f: float = raw
		if is_nan(f) or is_inf(f) or absf(f) > 1.0e6:
			return DEFAULT_FPS_CAP
		n = roundi(f)
	if n <= 0:
		return DEFAULT_FPS_CAP
	return VisualSettings.snap_fps_cap(n)
