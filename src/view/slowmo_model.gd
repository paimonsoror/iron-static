class_name SlowmoModel
extends RefCounted
## Presentation-time scale for the two allowed slow-mo moments (V1-14, art bible 6.6): boss death 0.4 s at
## 0.35x (ease in over 50 ms) and Cinder death 0.8 s at 0.25x. Pure math in wall-clock seconds. The factor is
## multiplied into the TickDriver's accumulator input only (fewer ticks per real second, same tick content), so
## state hashes never change. 1.0 when idle, under reduce motion, or at game speed above 2x.

enum Kind { NONE, BOSS_DEATH, CINDER_DEATH }

const BOSS_DURATION_S: float = 0.4
const BOSS_FACTOR: float = 0.35
const CINDER_DURATION_S: float = 0.8
const CINDER_FACTOR: float = 0.25
const EASE_IN_S: float = 0.05
const MAX_SPEED: int = 2

var kind: Kind = Kind.NONE
var elapsed_s: float = 0.0


## Factor for `kind` after `elapsed` wall seconds: eases 1 -> target over EASE_IN_S, holds, 1.0 once over.
static func factor_at(k: Kind, elapsed: float) -> float:
	var duration: float = 0.0
	var target: float = 1.0
	match k:
		Kind.BOSS_DEATH:
			duration = BOSS_DURATION_S
			target = BOSS_FACTOR
		Kind.CINDER_DEATH:
			duration = CINDER_DURATION_S
			target = CINDER_FACTOR
		_:
			return 1.0
	if elapsed < 0.0 or elapsed >= duration:
		return 1.0
	if elapsed < EASE_IN_S:
		return lerpf(1.0, target, elapsed / EASE_IN_S)
	return target


## Starts (or restarts) a slow-mo; a Cinder death is never replaced by a boss death.
func trigger(k: Kind) -> void:
	if kind == Kind.CINDER_DEATH and k == Kind.BOSS_DEATH:
		return
	kind = k
	elapsed_s = 0.0


func reset() -> void:
	kind = Kind.NONE
	elapsed_s = 0.0


## Advances the wall clock by `dt` and returns the factor to apply this frame.
func step(dt: float, speed: int, reduce_motion: bool) -> float:
	if kind == Kind.NONE:
		return 1.0
	elapsed_s += maxf(dt, 0.0)
	var f: float = factor_at(kind, elapsed_s)
	if f >= 1.0 and elapsed_s > EASE_IN_S:
		reset()
		return 1.0
	if reduce_motion or speed > MAX_SPEED:
		return 1.0
	return f
