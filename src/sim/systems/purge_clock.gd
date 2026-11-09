class_name PurgeClock
extends RefCounted
## PURGE wave-end rule (M4-03, Q72/Q73). Read-only over integer state. A wave is cleared when every plan entry
## of its own (not carried over) has spawned and every enemy born this wave is dead (boss included); enemies of
## older waves never block it. `SimWorld.step` also ends the wave at `backstop_ticks` (carry-over like TIMED).
## No lull: the next wave starts on the next tick.


## True when the wave's quota is destroyed. Call after `wave_tick` was advanced (the plan is built by then).
static func cleared(world: SimWorld) -> bool:
	if not world.plan.built or world.plan.remaining_unspawned() > 0:
		return false
	return _alive_born_this_wave(world) == 0


## Ticks after which a stalled PURGE wave ends anyway. A config without a backstop falls back to the TIMED
## wave length (impl) so a stalled wave can never hold the run forever.
static func backstop_ticks(world: SimWorld) -> int:
	var b: int = world.config.purge_backstop_ticks
	return b if b > 0 else Ticks.WAVE_TICKS


## Quota left in the current wave: unspawned own entries plus living enemies born this wave (M4-09 HUD).
static func remaining_quota(world: SimWorld) -> int:
	return world.plan.remaining_unspawned() + _alive_born_this_wave(world)


static func _alive_born_this_wave(world: SimWorld) -> int:
	var store: EnemyStore = world.enemies
	var n: int = 0
	for i: int in store.high_water:
		if store.alive[i] != 0 and store.born_wave[i] == world.wave:
			n += 1
	return n
