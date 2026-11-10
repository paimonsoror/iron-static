class_name BeamAfterglow
extends RefCounted
## Beam afterglow math (R1-06, review I-03). View only; nothing here reaches the sim. A shot keeps three timings:
## - the hot core (`BeamMath.FADE_S` 0.08 s, stretched to `CORE_SLOW_S` 0.12 s when the fire rate is under 2 shots a
##   second, so a slow beam is readable),
## - an afterglow on the glow layer that decays over `GLOW_S` (about 300 ms) after a short ramp-in,
## - a faint scorch line on the floor that fades over `SCORCH_S` (about 1 s).
## Both extras are capped per quality tier (HIGH, MID, LOW) and shortened by `CALM_MUL` under reduce motion, never
## removed. The MK I-IV tiers stay distinguishable because the afterglow reuses the tier's glow width and color.

const CORE_SLOW_S: float = 0.12
## Fire rates (shots in the last second, counting the new shot) below this get the stretched core.
const SLOW_RATE: int = 2
const GLOW_S: float = 0.30
const GLOW_PEAK: float = 0.34
const GLOW_RAMP_S: float = 0.04
## Afterglow width as a share of the tier's glow layer.
const GLOW_WIDTH_MUL: float = 0.8
const SCORCH_S: float = 1.0
const SCORCH_PEAK: float = 0.17
const SCORCH_PX: float = 4.0
const CALM_MUL: float = 0.5
## Live caps by `VisualQuality.Tier` index (HIGH, MID, LOW).
const GLOW_CAPS: Array[int] = [12, 6, 3]
const SCORCH_CAPS: Array[int] = [8, 4, 2]
const SCORCH_COLOR: Color = Color(0.95, 0.5, 0.18)


## Core fade length for a shot: 0.12 s under 2 shots a second, else 0.08 s.
static func core_fade_s(rate_hz: int) -> float:
	return CORE_SLOW_S if rate_hz < SLOW_RATE else BeamMath.FADE_S


static func glow_s(calm: bool) -> float:
	return GLOW_S * (CALM_MUL if calm else 1.0)


static func scorch_s(calm: bool) -> float:
	return SCORCH_S * (CALM_MUL if calm else 1.0)


## Afterglow alpha at `age_s`: a 40 ms ramp-in (it hands over from the live beam), then a quadratic decay to 0.
static func glow_alpha(age_s: float, calm: bool) -> float:
	var life: float = glow_s(calm)
	if age_s < 0.0 or age_s >= life:
		return 0.0
	var t: float = 1.0 - age_s / life
	return GLOW_PEAK * t * t * clampf(age_s / GLOW_RAMP_S, 0.0, 1.0)


## Scorch line alpha at `age_s`: linear fade over its lifetime.
static func scorch_alpha(age_s: float, calm: bool) -> float:
	var life: float = scorch_s(calm)
	if age_s < 0.0 or age_s >= life:
		return 0.0
	return SCORCH_PEAK * (1.0 - age_s / life)


static func glow_cap(tier: int) -> int:
	return GLOW_CAPS[clampi(tier, 0, GLOW_CAPS.size() - 1)]


static func scorch_cap(tier: int) -> int:
	return SCORCH_CAPS[clampi(tier, 0, SCORCH_CAPS.size() - 1)]
