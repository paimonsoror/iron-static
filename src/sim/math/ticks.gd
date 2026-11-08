class_name Ticks
extends RefCounted
## Time constants for the fixed 30 Hz simulation (GDD 02 section 6: one wave = 24 s).

const TICK_RATE: int = 30
const WAVE_TICKS: int = 720
const SPAWN_TICKS: int = 540
const LULL_TICKS: int = 180


## Converts seconds to the nearest whole tick count.
static func from_seconds(s: float) -> int:
	return roundi(s * float(TICK_RATE))
