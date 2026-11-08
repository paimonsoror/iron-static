class_name CinderAnim
extends RefCounted
## Pure animation curves and timelines of the Cinder rig (art bible 4.5, 6.5; GDD 02 section 12.1): wedge detach
## and re-form, core pulse, aim smoothing, hit shiver. No scene access, no allocation: unit-testable headless.

## Detach (entering a worse band): fly outward and fade.
const DETACH_S: float = 0.6
const DETACH_MIN_PX: float = 60.0
const DETACH_MAX_PX: float = 110.0
const DETACH_SCALE_END: float = 1.15
const DETACH_SPIN: float = 1.0
## Charred swap (intact to charred): crossfade.
const CHAR_S: float = 0.3
## Re-form (recovering): one wedge per step, 12 steps, 1.5 s total (GDD 02 section 12.1).
const REFORM_STEP_S: float = 0.125
const REFORM_STEPS: int = 12
const REFORM_SCALE_START: float = 0.7
const REFORM_FLASH_S: float = 0.06
## Hit feedback.
const SHIVER_S: float = 0.1
const SHIVER_PX: float = 2.0
const HIT_CORE_BOOST: float = 0.6
const HIT_S: float = 0.1
## Muzzle brightness decay after `notify_shot`.
const SHOT_S: float = 0.12
## Pulse rates in Hz (band 0 and 1, band 2, band 3 double beat).
const PULSE_HZ: float = 1.0
const PULSE_HZ_B2: float = 1.3
const HEART_HZ: float = 1.2
const EMBER_FLICKER_HZ: float = 6.0
const AIM_MAX_DEG_S: float = 540.0
## Exponential catch-up rate of the aim smoothing (1/s), capped by AIM_MAX_DEG_S.
const AIM_RATE: float = 18.0


## Distance (px) a wedge flies out when detaching; deterministic per wedge, within DETACH_MIN_PX..DETACH_MAX_PX.
static func detach_distance(wedge: int) -> float:
	var h: float = fposmod(sin(float(wedge) * 12.9898 + 4.1414) * 43758.5453, 1.0)
	return lerpf(DETACH_MIN_PX, DETACH_MAX_PX, h)


## Outward travel in px at `t` seconds since the detach start (ease-out, equals `detach_distance` at DETACH_S).
static func detach_offset(wedge: int, t: float) -> float:
	var u: float = clampf(t / DETACH_S, 0.0, 1.0)
	return detach_distance(wedge) * (1.0 - (1.0 - u) * (1.0 - u))


static func detach_alpha(t: float) -> float:
	return clampf(1.0 - t / DETACH_S, 0.0, 1.0)


static func detach_scale(t: float) -> float:
	return lerpf(1.0, DETACH_SCALE_END, clampf(t / DETACH_S, 0.0, 1.0))


## Extra rotation in radians, opposite directions for even and odd wedges.
static func detach_spin(wedge: int, t: float) -> float:
	var dir: float = 1.0 if wedge % 2 == 0 else -1.0
	return dir * DETACH_SPIN * clampf(t / DETACH_S, 0.0, 1.0)


## Seconds after the band change at which wedge `wedge` starts to re-form (0, 0.125, ... 1.375).
static func reform_start(wedge: int) -> float:
	return REFORM_STEP_S * float(clampi(wedge, 0, REFORM_STEPS - 1))


## Time at which the whole re-form schedule is done (1.5 s).
static func reform_total() -> float:
	return REFORM_STEP_S * float(REFORM_STEPS)


## Scale of a re-forming wedge `t` seconds after its own start: 0.7 to 1 over one step.
static func reform_scale(t: float) -> float:
	return lerpf(REFORM_SCALE_START, 1.0, clampf(t / REFORM_STEP_S, 0.0, 1.0))


## Teal-white edge flash 0..1 right after a wedge re-formed (linear fade over REFORM_FLASH_S).
static func reform_flash(t: float) -> float:
	if t < 0.0:
		return 0.0
	return clampf(1.0 - t / REFORM_FLASH_S, 0.0, 1.0)


## Core pulse 0..1 for `band` at time `t` seconds: sine 1 Hz (bands 0 and 1), 1.3 Hz (band 2), lub-dub 1.2 Hz (band 3).
static func pulse(band: int, t: float) -> float:
	if band >= 3:
		var p: float = fposmod(t * HEART_HZ, 1.0)
		return maxf(_beat(p, 0.08, 0.1), 0.7 * _beat(p, 0.30, 0.1))
	var hz: float = PULSE_HZ_B2 if band == 2 else PULSE_HZ
	return 0.5 + 0.5 * sin(TAU * hz * t)


static func _beat(p: float, center: float, width: float) -> float:
	var v: float = clampf(1.0 - absf(p - center) / width, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)


## Ember edge alpha: steady in band 1, 6 Hz flicker 0.7..1.0 in bands 2 and 3 (art bible 4.5).
static func ember_flicker(band: int, t: float) -> float:
	if band < 2:
		return 0.85
	return 0.85 + 0.15 * sin(TAU * EMBER_FLICKER_HZ * t)


## Moves `current` toward `target` (radians) along the shortest way, never faster than AIM_MAX_DEG_S.
static func aim_step(current: float, target: float, dt: float) -> float:
	var diff: float = wrapf(target - current, -PI, PI)
	var step: float = diff * (1.0 - exp(-AIM_RATE * dt))
	var cap: float = deg_to_rad(AIM_MAX_DEG_S) * dt
	return current + clampf(step, -cap, cap)


## Frame shiver offset `t` seconds after a hit: random within +-SHIVER_PX, exactly zero from SHIVER_S on.
static func shiver_offset(t: float, seed_value: int) -> Vector2:
	if t < 0.0 or t >= SHIVER_S:
		return Vector2.ZERO
	var n: float = floorf(t * 120.0) + float(seed_value) * 7.0
	var fade: float = 1.0 - t / SHIVER_S
	return Vector2(sin(n * 12.9898), sin(n * 78.233 + 1.7)) * (SHIVER_PX * fade)


## Core brightness boost 0..HIT_CORE_BOOST after a hit (linear over HIT_S).
static func hit_boost(t: float) -> float:
	if t < 0.0 or t >= HIT_S:
		return 0.0
	return HIT_CORE_BOOST * (1.0 - t / HIT_S)


## Muzzle brightness boost 0..1 after a shot (linear over SHOT_S).
static func shot_boost(t: float) -> float:
	if t < 0.0 or t >= SHOT_S:
		return 0.0
	return 1.0 - t / SHOT_S
