class_name SpeedRules
extends RefCounted
## Game speed rules (R1-03, GDD 02 section 14): the speeds, their unlock gates and the automatic fall-back. Pure
## static. Speed only means more sim ticks per frame (`TickDriver`); nothing here touches the sim.
## Unlocks follow the Foundry cap pattern: constants in the meta layer (not `sim_constants.csv`, which would change the
## config hash), gated on the best TIMED wave like the run rows, frames and PURGE. 1x and 2x are always available.
## Fall-back: above `FALL_SPEED` the effective speed drops to `FALL_SPEED` while the hull is below `FALL_BELOW` or a
## boss is alive, and returns to the chosen speed once the hull is at or above `BACK_AT` with no boss (hysteresis band
## between the two keeps the state).

const SPEEDS: Array[int] = [1, 2, 4, 8]
## Best TIMED wave needed for the speed at the same index.
const UNLOCK_WAVES: Array[int] = [0, 0, 30, 60]
const FALL_SPEED: int = 2
const FALL_BELOW: float = 0.75
const BACK_AT: float = 0.80


## Speeds available at `best_timed`, ascending.
static func unlocked(best_timed: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in SPEEDS.size():
		if best_timed >= UNLOCK_WAVES[i]:
			out.append(SPEEDS[i])
	return out


static func is_unlocked(speed: int, best_timed: int) -> bool:
	return unlocked(best_timed).has(speed)


## The speed after `current` in the unlocked cycle (wraps to 1x). An unknown or locked `current` gives 1x.
static func cycle_next(current: int, best_timed: int) -> int:
	var list: Array[int] = unlocked(best_timed)
	var at: int = list.find(current)
	if at < 0:
		return list[0]
	return list[(at + 1) % list.size()]


## (speed, wave) of the next locked speed, or (0, 0) when all are unlocked.
static func next_unlock(best_timed: int) -> Vector2i:
	for i: int in SPEEDS.size():
		if best_timed < UNLOCK_WAVES[i]:
			return Vector2i(SPEEDS[i], UNLOCK_WAVES[i])
	return Vector2i.ZERO


## The next fall-back state (`fallen` = effective speed is held at `FALL_SPEED`).
static func next_fallen(fallen: bool, chosen: int, hull_frac: float, boss_alive: bool) -> bool:
	if chosen <= FALL_SPEED:
		return false
	if boss_alive or hull_frac < FALL_BELOW:
		return true
	if hull_frac >= BACK_AT:
		return false
	return fallen


static func effective(chosen: int, fallen: bool) -> int:
	return mini(chosen, FALL_SPEED) if fallen else chosen
