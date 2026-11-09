class_name SettingsModel
extends RefCounted
## Pure option lists, string keys and example texts of the settings screen (M3-18). No Node access.

const KEY_SFX: String = "sfx"
const KEY_MUSIC: String = "music"
const KEY_MUTED: String = "muted"
const KEY_REDUCE_MOTION: String = "reduce_motion"
const KEY_SHAKE: String = "shake"
const KEY_SCANLINES: String = "scanlines"
const KEY_NUMBER_FORMAT: String = "number_format"
const KEY_FPS_CAP: String = "fps_cap"
const KEY_HAPTICS: String = "haptics"
const KEY_COLORBLIND: String = "colorblind"
const KEY_HIGH_CONTRAST: String = "high_contrast"

## Control order on screen.
const ORDER: Array[String] = [
	KEY_SFX,
	KEY_MUSIC,
	KEY_MUTED,
	KEY_REDUCE_MOTION,
	KEY_SHAKE,
	KEY_SCANLINES,
	KEY_NUMBER_FORMAT,
	KEY_FPS_CAP,
	KEY_HAPTICS,
	KEY_COLORBLIND,
	KEY_HIGH_CONTRAST,
]
## Row label string key per setting ("Sound" is the `sfx` volume).
const LABEL_KEYS: Dictionary = {
	KEY_SFX: "settings.sound",
	KEY_MUSIC: "settings.music",
	KEY_MUTED: "settings.mute",
	KEY_REDUCE_MOTION: "settings.reduce_motion",
	KEY_SHAKE: "settings.shake",
	KEY_SCANLINES: "settings.scanlines",
	KEY_NUMBER_FORMAT: "settings.number_format",
	KEY_FPS_CAP: "settings.fps_cap",
	KEY_HAPTICS: "settings.haptics",
	KEY_COLORBLIND: "settings.colorblind",
	KEY_HIGH_CONTRAST: "settings.high_contrast",
}
## Example number for the number format: 12345678 reads differently in all three styles.
const EXAMPLE_VALUE: String = "12345678"
## Volume slider step.
const VOLUME_STEP: float = 0.05


static func label_key(setting: String) -> String:
	var k: String = LABEL_KEYS.get(setting, "")
	return k


## Option names of a choice setting, in display order.
static func options(setting: String) -> Array[String]:
	match setting:
		KEY_SHAKE, KEY_SCANLINES:
			return PlayerSettings.LEVEL_NAMES
		KEY_NUMBER_FORMAT:
			return NumberFormat.STYLE_NAMES
		KEY_COLORBLIND:
			return PlayerSettings.COLORBLIND_NAMES
		KEY_FPS_CAP:
			var out: Array[String] = []
			for c: int in VisualSettings.FPS_CAPS:
				out.append(str(c))
			return out
	return []


## String key of one option's button text.
static func option_key(setting: String, option: String) -> String:
	if setting == KEY_FPS_CAP:
		return "settings.opt.fps" + option
	return "settings.opt." + option


static func option_keys(setting: String) -> Array[String]:
	var out: Array[String] = []
	for o: String in options(setting):
		out.append(option_key(setting, o))
	return out


static func index_of(setting: String, option: String) -> int:
	return maxi(options(setting).find(option), 0)


## String key of a colorblind mode's full name (the segment buttons carry short names).
static func colorblind_full_key(mode: String) -> String:
	return "settings.cb." + mode


## "70%" for a 0..1 volume.
static func volume_text(v: float) -> String:
	return "%d%%" % roundi(clampf(v, 0.0, 1.0) * 100.0)


## Snaps a volume to the slider step in 0..1.
static func snap_volume(v: float) -> float:
	return clampf(snappedf(v, VOLUME_STEP), 0.0, 1.0)


## The example number in a style (NumberFormat.SHORT / SCIENTIFIC / ENGINEERING): 12.3M, 1.23e7, 12.3e6.
static func number_example(style: int) -> String:
	return NumberFormat.format(BigNum.parse(EXAMPLE_VALUE), style)


## True for the choices reduce motion forces off (the stored choice is kept).
static func dimmed_by_reduce_motion(setting: String) -> bool:
	return setting == KEY_SHAKE or setting == KEY_SCANLINES
