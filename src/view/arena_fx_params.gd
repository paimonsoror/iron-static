class_name ArenaFxParams
extends RefCounted
## Pure mapping from view state to arena shader uniform values (art bible 6.7, V1-08). No nodes, no shader calls:
## `ArenaBackground` feeds these into the two materials, tests pin the numbers.

const SWEEP_PERIOD_S: float = 8.0
const PULSE_PERIOD_S: float = 4.0
## Grid and pulse stay at full strength up to this many live enemies, then fade linearly to 0 at DENSITY_END.
const DENSITY_START: int = 100
const DENSITY_END: int = 200
## Low-HP haze peak by integrity band (art bible 6.5): band 3 pulses up to 0.45, band 2 is a faint static 8%.
const LOW_HP_BAND3: float = 0.45
const LOW_HP_BAND2: float = 0.08
## Static haze used instead of the pulse (reduce motion, tiers without the vignette pulse).
const LOW_HP_STATIC: float = 0.3
## Art px per meter the floor SVG was authored at (1080 / 32 m).
const ART_PX_PER_M: float = 33.75


## Grid/pulse strength 0..1 for `alive` enemies: 1 up to 100, 0.5 at 150, 0 from 200.
static func density_fade(alive: int) -> float:
	if alive <= DENSITY_START:
		return 1.0
	return clampf(1.0 - float(alive - DENSITY_START) / float(DENSITY_END - DENSITY_START), 0.0, 1.0)


## Low-HP haze peak. Band 3 pulses (0.45) unless `pulse` is false, then static 0.3; band 2 is 0.08 always.
static func low_hp(band: int, pulse: bool) -> float:
	if band >= 3:
		return LOW_HP_BAND3 if pulse else LOW_HP_STATIC
	if band == 2:
		return LOW_HP_BAND2
	return 0.0


## True when the haze may pulse: the tier allows it and reduce motion is off.
static func pulse_allowed(settings: VisualSettings) -> bool:
	return settings.quality.vignette_pulse and not settings.reduce_motion


static func sweep_enabled(settings: VisualSettings) -> bool:
	return settings.quality.sweep and not settings.reduce_motion


static func range_pulse_enabled(settings: VisualSettings) -> bool:
	return settings.quality.range_pulse and not settings.reduce_motion


## Sweep phase 0..1 of the view clock (one turn per 8 s).
static func sweep_phase(clock_s: float) -> float:
	return fposmod(clock_s / SWEEP_PERIOD_S, 1.0)


## Range-pulse phase 0..1 of the view clock (one pulse per 4 s).
static func pulse_phase(clock_s: float) -> float:
	return fposmod(clock_s / PULSE_PERIOD_S, 1.0)


## Optic ring radius in px (remapped like the enemies); 0 hides the ring.
static func optic_px(range_m: float, ppm: float) -> float:
	if range_m <= 0.0:
		return 0.0
	return ViewMath.map_dist(range_m, ppm)


## Floor art scale: art pixels to local pixels.
static func art_scale(ppm: float) -> float:
	return ppm / ART_PX_PER_M


## 1.0 or 0.0 for shader float switches.
static func flag(on: bool) -> float:
	return 1.0 if on else 0.0
