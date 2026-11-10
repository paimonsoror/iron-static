class_name RingAnim
extends RefCounted
## Pure timing and geometry for the upgrade row effects (V1-17, art bible 7.3): the gold milestone ring sweep (2 s),
## its 0.4 s expansion on a milestone purchase, the affordable cost pulse (1.2 s) and the 120 ms purchase flash.
## No nodes, no allocation: `RowFx` feeds it the clock and draws the result.

const SWEEP_S: float = 2.0
const EXPAND_S: float = 0.4
const PULSE_S: float = 1.2
const FLASH_S: float = 0.12
## A row rings within this many levels below a multiple of the milestone step (level 0 never rings).
const RING_LEVELS: int = 3


## True for levels 22..24, 47..49 ...: within RING_LEVELS below the next multiple of `every` (the run milestone step,
## 25 with the shipped data; the documented fallback when the caller passes none); level 0 excluded.
static func ring_for_level(level: int, every: int = Curves.FALLBACK_RUN_STEP) -> bool:
	if level <= 0:
		return false
	var to_next: int = every - (level % every)
	return to_next <= RING_LEVELS


## Position (0..1) of the sweep highlight along the ring perimeter at time `t_s`.
static func sweep(t_s: float) -> float:
	return fposmod(t_s / SWEEP_S, 1.0)


## 0..1..0 smooth pulse with period PULSE_S (0 at t = 0).
static func pulse(t_s: float) -> float:
	return 0.5 - 0.5 * cos(TAU * t_s / PULSE_S)


## Expansion progress 0..1 after `age_s` seconds (clamped); >= 1 means finished.
static func expand_progress(age_s: float) -> float:
	return clampf(age_s / EXPAND_S, 0.0, 1.0)


## Point on the rectangle perimeter (clockwise from the top-left corner) at fraction `u` (wraps); `size` is the rect.
static func perimeter_point(size: Vector2, u: float) -> Vector2:
	var per: float = 2.0 * (size.x + size.y)
	var d: float = fposmod(u, 1.0) * per
	if d < size.x:
		return Vector2(d, 0.0)
	d -= size.x
	if d < size.y:
		return Vector2(size.x, d)
	d -= size.y
	if d < size.x:
		return Vector2(size.x - d, size.y)
	d -= size.x
	return Vector2(0.0, size.y - d)
