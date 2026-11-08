class_name HeartbeatModel
extends RefCounted
## Pure double-beat ("lub-dub") curve shared by the low-HP overlay, Cinder's core and anything else that pulses with
## band 3 (art bible 6.5, V1-15). One beat per 1/1.2 s; the second pulse follows 0.18 s after the first at 70%
## amplitude. Output 0..1. Compact bumps, so there are exactly two local maxima per period.

const HZ: float = 1.2
const GAP_S: float = 0.18
const SECOND_AMP: float = 0.7
## Phase (0..1 of the period) of the first peak and half-width of each bump.
const FIRST_PHASE: float = 0.08
const HALF_WIDTH: float = 0.1
## Overlay intensity at band 3: base plus this much of the beat (art bible 6.5).
const BASE_B3: float = 0.25
const SWING_B3: float = 0.20


static func period_s() -> float:
	return 1.0 / HZ


## Beat value 0..1 at time `t_s` (any clock, wraps).
static func value(t_s: float) -> float:
	var p: float = fposmod(t_s * HZ, 1.0)
	return maxf(_bump(p, FIRST_PHASE), SECOND_AMP * _bump(p, FIRST_PHASE + GAP_S * HZ))


static func _bump(p: float, center: float) -> float:
	var v: float = clampf(1.0 - absf(p - center) / HALF_WIDTH, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)
