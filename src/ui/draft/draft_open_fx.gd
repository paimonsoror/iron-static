class_name DraftOpenFx
extends RefCounted
## Numbers of `vfx_draft_open` (07 s5, M4-16): two amber rings expanding from the middle of the frozen battle under
## the cards, about half a second, drawn by the overlay in wall time (the sim clock is frozen behind a draft, so a
## sim-time particle would stand still). Pure. Reduce motion draws no ring (`ring_count(true)` is 0) and shows the
## cards at once.

const DURATION_S: float = 0.55
const STAGGER_S: float = 0.14
const RINGS: int = 2
const MAX_RADIUS: float = 760.0
const START_RADIUS: float = 60.0
const WIDTH_PX: float = 8.0
const FADE_IN_S: float = 0.18


static func ring_count(reduce_motion: bool) -> int:
	return 0 if reduce_motion else RINGS


## Time the whole effect is over (the last ring faded).
static func total_s() -> float:
	return DURATION_S + STAGGER_S * float(RINGS - 1)


## Progress 0..1 of ring `i` at `t` seconds since open (0 before it starts, 1 when done).
static func progress(i: int, t: float) -> float:
	return clampf((t - STAGGER_S * float(i)) / DURATION_S, 0.0, 1.0)


static func radius(p: float) -> float:
	var eased: float = 1.0 - (1.0 - p) * (1.0 - p)
	return lerpf(START_RADIUS, MAX_RADIUS, eased)


## Ring alpha: full at the start, gone at the end; hidden outside the ring's life.
static func alpha(p: float) -> float:
	if p <= 0.0 or p >= 1.0:
		return 0.0
	return 0.85 * (1.0 - p)


## Card fade-in 0..1 (1 at once under reduce motion).
static func card_fade(t: float, reduce_motion: bool) -> float:
	return 1.0 if reduce_motion else clampf(t / FADE_IN_S, 0.0, 1.0)
