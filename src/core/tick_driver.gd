class_name TickDriver
extends RefCounted
## Converts frame time into fixed sim ticks (TECH_ARCHITECTURE 2.2). `acc += delta * speed`,
## `ticks = floor(acc / DT)`, `acc -= ticks * DT`; the tick length is never scaled, speed only means more
## ticks per frame. At most MAX_TICKS_PER_FRAME ticks run per call and the frame's sim budget (default 10 ms,
## wall clock) is respected; ticks beyond either limit are dropped (not carried), which sets `throttled`.
## Lives in src/core (not sim) because it reads the wall clock for the budget only; it never affects what a
## tick computes. At least one tick runs per call when any is due, so a zero budget degrades but never stalls.

const MAX_TICKS_PER_FRAME: int = 8
const DEFAULT_BUDGET_USEC: int = 10000
const DT: float = SimWorld.DT

## Wall-clock budget per advance() call in microseconds (tests force it to 0).
var budget_usec: int = DEFAULT_BUDGET_USEC
## Do not step once `world.tick` reaches this value (0 = no limit). Lets tests stop on an exact tick.
var tick_limit: int = 0
## True when the last advance() dropped ticks (cap or budget); the UI shows a throttled indicator.
var throttled: bool = false
## Leftover simulated time in seconds (0 <= acc < DT after each call).
var acc: float = 0.0


## Runs the ticks due for `delta` seconds of frame time at `speed` (1-4). Returns how many ticks ran.
func advance(world: SimWorld, delta: float, speed: int) -> int:
	throttled = false
	if delta <= 0.0 or speed <= 0:
		return 0
	acc += delta * float(speed)
	var due: int = floori(acc / DT)
	acc -= float(due) * DT
	if acc < 0.0:
		acc = 0.0
	var allowed: int = mini(due, MAX_TICKS_PER_FRAME)
	var start_usec: int = Time.get_ticks_usec()
	var ran: int = 0
	while ran < allowed:
		if world.is_over() or (tick_limit > 0 and world.tick >= tick_limit):
			return ran  # a finished or limited world is not "throttled"
		if ran > 0 and Time.get_ticks_usec() - start_usec >= budget_usec:
			break
		world.step()
		ran += 1
	if ran < due:
		throttled = true
	return ran
