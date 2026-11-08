class_name VisualSettings
extends RefCounted
## Holder of the current visual quality and the user-facing visual options (art bible 6.6, 6.8, 9.3). Plain
## RefCounted, no autoload: `Game` creates one from the user args and hands it to the debug overlay; view
## code receives it by injection (`setup_visual(settings)` in later V1 tasks) and reads the `effective_*`
## helpers every frame (cheap). Listen to `quality_changed` for switches that need rebuilding a material.

signal quality_changed(tier: int)

enum Shake { OFF, LOW, NORMAL }

const ARG_SHAKE: String = "--shake="
const SHAKE_NAMES: Array[String] = ["off", "low", "normal"]
const SHAKE_PX: Array[float] = [0.0, 5.0, 10.0]
const DEFAULT_SCANLINE_INTENSITY: float = 0.06

var quality: VisualQuality = VisualQuality.high()
var screen_shake: Shake = Shake.LOW
var reduce_motion: bool = false
## Scanline opacity (Q44: 0.06 default, 0.03 low, 0 off).
var scanline_intensity: float = DEFAULT_SCANLINE_INTENSITY


## Builds settings from the user args (`--quality=`, `--shake=`); absent args give the defaults.
static func from_args(args: PackedStringArray) -> VisualSettings:
	var s := VisualSettings.new()
	s.quality = VisualQuality.for_tier(VisualQuality.tier_from_args(args))
	for a: String in args:
		if a.begins_with(ARG_SHAKE):
			s.screen_shake = parse_shake(a.substr(ARG_SHAKE.length()))
	return s


## Parses a shake name; unknown text logs a warning and gives LOW (the default).
static func parse_shake(text: String) -> Shake:
	var idx: int = SHAKE_NAMES.find(text.strip_edges().to_lower())
	if idx < 0:
		Log.warn("unknown shake '%s' (use off|low|normal), falling back to low" % text)
		return Shake.LOW
	return idx as Shake


## Switches the tier (replaces `quality` with the preset) and emits `quality_changed`.
func set_tier(t: VisualQuality.Tier) -> void:
	quality = VisualQuality.for_tier(t)
	quality_changed.emit(int(t))


## Shake offset limit in px: 0 with reduce motion or Off, else the lower of the user setting and the tier cap.
func effective_shake_px() -> float:
	if reduce_motion:
		return 0.0
	return minf(SHAKE_PX[screen_shake], quality.shake_max_px)


## Scanline opacity to draw: 0 when the tier disallows them or reduce motion is on.
func effective_scanlines() -> float:
	if reduce_motion or not quality.scanlines:
		return 0.0
	return scanline_intensity
