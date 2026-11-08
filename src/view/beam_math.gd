class_name BeamMath
extends RefCounted
## Pure beam helpers (art bible 6.1, GDD 07 section 5.3): layer widths, deterministic jitter, the
## fade curve, the merge rule for high fire rates and beam geometry. No nodes, no globals.

const FADE_S: float = 0.08
const GLOW_PX: float = 36.0
const CORE_PX: float = 8.0
const HOT_PX: float = 3.0
const CRIT_WIDTH_MUL: float = 1.5
const GLOW_ALPHA: float = 0.55
## Width jitter +-12 % and lateral wobble +-2 px.
const JITTER_WIDTH: float = 0.12
const WOBBLE_PX: float = 2.0
## More than this many shots in the last second merge into one sustained beam.
const MERGE_RATE_HZ: float = 8.0
const RATE_WINDOW_S: float = 1.0
## Beams whose end points lie within this distance count as the same target.
const MERGE_END_PX: float = 8.0
## Brightness floor of a merged beam between shots.
const MERGED_FLOOR: float = 0.5
## Muzzle flash lifetimes and sizes (art bible 6.1).
const FLASH_S: float = 0.06
const CONE_S: float = 0.05
const FLASH_PX: float = 64.0
const CONE_PX: float = 90.0
const CRIT_FLARE_PX: float = 90.0


## Linear fade 1 -> 0 over FADE_S; 0 for unborn or expired beams.
static func fade_alpha(age_s: float) -> float:
	if age_s < 0.0 or age_s >= FADE_S:
		return 0.0
	return 1.0 - age_s / FADE_S


## Alpha of a merged (sustained) beam: pulses between MERGED_FLOOR and 1 at the shot rate while shots keep
## refreshing it, then fades out over one more FADE_S.
static func merged_alpha(age_s: float) -> float:
	if age_s < 0.0 or age_s >= 2.0 * FADE_S:
		return 0.0
	if age_s < FADE_S:
		return MERGED_FLOOR + (1.0 - MERGED_FLOOR) * (1.0 - age_s / FADE_S)
	return MERGED_FLOOR * (1.0 - (age_s - FADE_S) / FADE_S)


## Layer widths (glow, core, hot) in px for one beam; `width_mul` is the jitter factor.
static func widths(crit: bool, width_mul: float = 1.0) -> Vector3:
	var m: float = width_mul * (CRIT_WIDTH_MUL if crit else 1.0)
	return Vector3(GLOW_PX * m, CORE_PX * m, HOT_PX * m)


## Deterministic jitter from the shot counter: x = width multiplier in [1 - J, 1 + J], y = lateral wobble in px.
static func jitter(counter: int) -> Vector2:
	var h: int = _hash(counter)
	var u: float = float(h & 0xFFFF) / 65535.0
	var v: float = float((h >> 16) & 0xFFFF) / 65535.0
	return Vector2(1.0 + (u * 2.0 - 1.0) * JITTER_WIDTH, (v * 2.0 - 1.0) * WOBBLE_PX)


## Number of timestamps in (now - RATE_WINDOW_S, now]: the shot rate in Hz over the last second.
static func shots_in_window(times: PackedFloat64Array, now_s: float) -> int:
	var n: int = 0
	for t: float in times:
		if t > now_s - RATE_WINDOW_S and t <= now_s:
			n += 1
	return n


## True when the rate (shots in the last second, counting the new one) calls for a sustained beam.
static func should_merge(rate_hz: int) -> bool:
	return float(rate_hz) > MERGE_RATE_HZ


## Beam length and angle from `start` to `end`.
static func length_angle(start: Vector2, end: Vector2) -> Vector2:
	var d: Vector2 = end - start
	return Vector2(d.length(), d.angle())


## Core color: `Palette.LASER_CORE`, pure white on a crit.
static func core_color(crit: bool) -> Color:
	return Color.WHITE if crit else Palette.LASER_CORE


## Cap rect in a frame whose origin is the beam end and +x points along the beam toward it: an h x h quad whose
## bright right edge sits on the origin. The target-end cap draws in a frame rotated by angle + PI (pivot (1, 0.5)).
static func cap_rect(height: float) -> Rect2:
	return Rect2(-height, -height * 0.5, height, height)


## Muzzle flare scale 0.6 -> 1.3 over FLASH_S, 0 afterwards.
static func flash_scale(age_s: float) -> float:
	if age_s < 0.0 or age_s >= FLASH_S:
		return 0.0
	return lerpf(0.6, 1.3, age_s / FLASH_S)


## Muzzle flash alpha: 1 -> 0 over FLASH_S.
static func flash_alpha(age_s: float) -> float:
	if age_s < 0.0 or age_s >= FLASH_S:
		return 0.0
	return 1.0 - age_s / FLASH_S


static func cone_alpha(age_s: float) -> float:
	if age_s < 0.0 or age_s >= CONE_S:
		return 0.0
	return 1.0 - age_s / CONE_S


static func _hash(counter: int) -> int:
	var x: int = (counter * 0x9E3779B1 + 0x7F4A7C15) & 0xFFFFFFFF
	x = ((x ^ (x >> 16)) * 0x85EBCA6B) & 0xFFFFFFFF
	x = ((x ^ (x >> 13)) * 0xC2B2AE35) & 0xFFFFFFFF
	return (x ^ (x >> 16)) & 0xFFFFFFFF
