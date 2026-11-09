class_name ColdOpenModel
extends RefCounted
## Timing of the cold open (07 s3, M4-26): three amber system lines fade in one after the other, then Cinder fades in
## below them, then the screen ends by itself. Pure static; `t` is seconds since the screen was shown. Reduce motion
## shows every line and Cinder at once and holds `REDUCED_TOTAL_S` seconds.

const LINE_START_S: PackedFloat32Array = [0.4, 1.7, 3.0]
const LINE_FADE_S: float = 0.6
const CINDER_START_S: float = 4.2
const CINDER_FADE_S: float = 1.2
const TOTAL_S: float = 6.4
const REDUCED_TOTAL_S: float = 3.0


## Opacity 0-1 of line `index` (0-2).
static func line_alpha(index: int, t: float, reduced: bool) -> float:
	if reduced:
		return 1.0
	return clampf((t - LINE_START_S[index]) / LINE_FADE_S, 0.0, 1.0)


static func cinder_alpha(t: float, reduced: bool) -> float:
	if reduced:
		return 1.0
	return clampf((t - CINDER_START_S) / CINDER_FADE_S, 0.0, 1.0)


static func total_s(reduced: bool) -> float:
	return REDUCED_TOTAL_S if reduced else TOTAL_S


static func finished(t: float, reduced: bool) -> bool:
	return t >= total_s(reduced)
