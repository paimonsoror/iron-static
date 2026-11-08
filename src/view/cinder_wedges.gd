class_name CinderWedges
extends RefCounted
## Pure skin-wedge state per exposure band (GDD 02 section 12.1, GDD 07 section 5.6).
## No scene dependency: unit-testable headless.

const WEDGE_COUNT: int = 12
const INTACT: int = 0
const CHARRED: int = 1
const GONE: int = 2

## Fixed order of loss (wedge indices).
const BAND1_CHARRED: Array[int] = [2, 7, 10]
const BAND2_GONE: Array[int] = [0, 2, 3, 5, 7, 8, 10, 11]


## Returns WEDGE_COUNT values (INTACT, CHARRED, GONE). Out-of-range bands are clamped to 0..3.
static func states(band: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var b: int = clampi(band, 0, 3)
	out.resize(WEDGE_COUNT)
	match b:
		0:
			out.fill(INTACT)
		1:
			out.fill(INTACT)
			for i: int in BAND1_CHARRED:
				out[i] = CHARRED
		2:
			out.fill(CHARRED)
			for i: int in BAND2_GONE:
				out[i] = GONE
		_:
			out.fill(GONE)
	return out
