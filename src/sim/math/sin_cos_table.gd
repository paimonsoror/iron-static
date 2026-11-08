class_name SinCosTable
extends RefCounted
## 4096-entry sine/cosine lookup table. Angles are integer indices (one full turn = SIZE), so spawn angles
## are stored as ints and positions are reproducible. Indices wrap (masked), negative values are fine.

const SIZE: int = 4096
const MASK: int = SIZE - 1

static var _cos: PackedFloat64Array = _build(true)
static var _sin: PackedFloat64Array = _build(false)


static func cos_i(idx: int) -> float:
	return _cos[idx & MASK]


static func sin_i(idx: int) -> float:
	return _sin[idx & MASK]


static func _build(use_cos: bool) -> PackedFloat64Array:
	var out: PackedFloat64Array = PackedFloat64Array()
	if out.resize(SIZE) != OK:
		push_error("SinCosTable: resize failed")
		return out
	for i: int in SIZE:
		var a: float = TAU * float(i) / float(SIZE)
		out[i] = cos(a) if use_cos else sin(a)
	return out
