class_name Rng
extends RefCounted
## PCG32 (XSH-RR) random generator. Integer ops only; GDScript int is signed 64-bit with
## arithmetic >>, so every shift of a 64-bit state is masked to emulate unsigned shifts.

const MULT: int = 6364136223846793005
const MASK32: int = 0xFFFFFFFF
const MASK46: int = 0x3FFFFFFFFFFF  # low 46 bits: logical (state >> 18)
const MASK5: int = 31
const FNV_OFFSET: int = -3750763034362895579  # 0xcbf29ce484222325 as signed int64
const FNV_PRIME: int = 1099511628211  # 0x100000001b3
const TWO_POW_32: int = 4294967296
const FLOAT_BITS: int = 24
const FLOAT_SCALE: float = 1.0 / 16777216.0

var _state: int = 0
var _inc: int = 1


func _init(seed_value: int, stream_id: int = 0) -> void:
	# Reference pcg32_srandom_r(initstate, initseq).
	_state = 0
	_inc = (stream_id << 1) | 1
	_step()
	_state += seed_value
	_step()


## Derives an independent generator for a named stream (seed XOR FNV-1a-64 of the name).
static func derive(seed_value: int, stream_name: String) -> Rng:
	var h: int = FNV_OFFSET
	for b: int in stream_name.to_utf8_buffer():
		h = (h ^ b) * FNV_PRIME
	return Rng.new(seed_value ^ h, 0)


func _step() -> int:
	var old: int = _state
	_state = old * MULT + _inc
	return old


## Next uniformly distributed unsigned 32-bit value (0 .. 2^32-1).
func next_u32() -> int:
	var old: int = _step()
	var x: int = ((old >> 18) & MASK46) ^ old
	var xorshifted: int = (x >> 27) & MASK32
	var rot: int = (old >> 59) & MASK5
	return ((xorshifted >> rot) | (xorshifted << ((32 - rot) & MASK5))) & MASK32


## Float in [0, 1) with 24-bit resolution.
func next_float() -> float:
	return float(next_u32() >> (32 - FLOAT_BITS)) * FLOAT_SCALE


## Unbiased integer in [lo, hi_inclusive] (rejection sampling).
func range_int(lo: int, hi_inclusive: int) -> int:
	var span: int = hi_inclusive - lo + 1
	if span <= 1:
		return lo
	var threshold: int = (TWO_POW_32 - span) % span
	var r: int = next_u32()
	while r < threshold:
		r = next_u32()
	return lo + r % span


func chance(p: float) -> bool:
	return next_float() < p


func get_state() -> PackedInt64Array:
	return PackedInt64Array([_state, _inc])


func set_state(s: PackedInt64Array) -> void:
	_state = s[0]
	_inc = s[1]
