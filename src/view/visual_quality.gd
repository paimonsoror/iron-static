class_name VisualQuality
extends Resource
## Visual quality tier (art bible 9.3, V1-03): one typed bundle of view-side cost switches. View-only: it never
## feeds the sim (TECH_ARCHITECTURE 2.7). Every effect with a cost reads its switch from here (through
## `VisualSettings.quality`), so the fallback ladder is one place. Presets are `high()`, `mid()`, `low()`.
## Selection: `--quality=high|mid|low` user arg (`parse_tier`), the debug overlay buttons, later M6 detection.
## Fallback ladder order when over budget (TECH 2.7): shake and particles, then scanlines/motes, then glow
## sheets, then crowd flipbooks frozen at frame 0.

enum Tier { HIGH, MID, LOW }

const ARG_QUALITY: String = "--quality="
const TIER_NAMES: Array[String] = ["high", "mid", "low"]
## Density-based glow reduction (V1-GATE decision 3): full strength up to GLOW_RAMP_START alive enemies, linear
## down to GLOW_MIN_STRENGTH at GLOW_RAMP_END and beyond.
const GLOW_RAMP_START: int = 40
const GLOW_RAMP_END: int = 165
const GLOW_MIN_STRENGTH: float = 0.45

@export var tier: Tier = Tier.HIGH
## Hard cap of live particles in the particle ring.
@export var particle_cap: int = 400
## Scanline overlay allowed (the intensity itself is `VisualSettings.scanline_intensity`).
@export var scanlines: bool = true
## Ambient drifting motes (24 specks).
@export var motes: bool = true
## Glow sheets sampled (second texture); false = the alternate material without it.
@export var glow_sheets: bool = true
## Radar sweep wedge in the arena shader.
@export var sweep: bool = true
## Expanding range-ring pulse every 4 s.
@export var range_pulse: bool = true
## Low-HP vignette pulse.
@export var vignette_pulse: bool = true
## Expanding ring in an impact burst.
@export var impact_rings: bool = true
## Sparks per hit before the density LOD of art bible 6.4.
@export var sparks_per_hit: int = 6
## Cinder wedges animate (false = snap between states).
@export var wedge_anim: bool = true
## Maximum screen shake offset in px at 1080 wide (the user setting can only lower it).
@export var shake_max_px: float = 10.0


static func high() -> VisualQuality:
	return VisualQuality.new()


static func mid() -> VisualQuality:
	var q := VisualQuality.new()
	q.tier = Tier.MID
	q.particle_cap = 200
	q.scanlines = false
	q.motes = false
	q.range_pulse = false
	q.impact_rings = false
	q.shake_max_px = 5.0
	return q


static func low() -> VisualQuality:
	var q := VisualQuality.mid()
	q.tier = Tier.LOW
	q.particle_cap = 80
	q.glow_sheets = false
	q.sweep = false
	q.vignette_pulse = false
	q.sparks_per_hit = 2
	q.wedge_anim = false
	return q


static func for_tier(t: Tier) -> VisualQuality:
	match t:
		Tier.MID:
			return mid()
		Tier.LOW:
			return low()
	return high()


## Parses a tier name (case-insensitive). Unknown or empty text logs a warning and gives HIGH.
static func parse_tier(text: String) -> Tier:
	var idx: int = TIER_NAMES.find(text.strip_edges().to_lower())
	if idx < 0:
		Log.warn("unknown quality '%s' (use high|mid|low), falling back to high" % text)
		return Tier.HIGH
	return idx as Tier


## Tier from the `--quality=<name>` user arg; HIGH when the arg is absent.
static func tier_from_args(args: PackedStringArray) -> Tier:
	for a: String in args:
		if a.begins_with(ARG_QUALITY):
			return parse_tier(a.substr(ARG_QUALITY.length()))
	return Tier.HIGH


func tier_name() -> String:
	return TIER_NAMES[tier]


## Enemy glow strength 0-1 for `alive` enemies (density ramp); 0 when glow sheets are off.
func glow_strength(alive: int) -> float:
	if not glow_sheets:
		return 0.0
	if alive <= GLOW_RAMP_START:
		return 1.0
	var t: float = clampf(float(alive - GLOW_RAMP_START) / float(GLOW_RAMP_END - GLOW_RAMP_START), 0.0, 1.0)
	return lerpf(1.0, GLOW_MIN_STRENGTH, t)
