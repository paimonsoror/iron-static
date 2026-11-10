class_name SpeedLoad
extends RefCounted
## High-speed load shedding (R1-03). At 4x and 8x the sim runs 4-8 ticks per frame, so everything that scales with
## events per frame (SFX voices, haptic pulses, damage numbers, spark and kill particles) is cut: 1.0 up to 2x, 0.5 at
## 4x, 0.25 at 8x. View and audio only; the sim never reads it.


static func factor(speed: int) -> float:
	if speed >= 8:
		return 0.25
	if speed >= 4:
		return 0.5
	return 1.0


## `n` scaled by the speed's factor, rounded, never below 1 for a positive `n`.
static func scaled(n: int, speed: int) -> int:
	if n <= 0:
		return 0
	return maxi(roundi(float(n) * factor(speed)), 1)
