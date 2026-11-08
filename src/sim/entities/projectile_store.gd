class_name ProjectileStore
extends RefCounted
## Struct-of-arrays projectile store with a free list (TECH_ARCHITECTURE 2.4).
##
## Holds only moving entities (lancer bolts now; missiles and mines later).
## Same contract as `EnemyStore`: arrays sized once, loops bounded by
## `high_water`, `alloc` returns -1 when full (callers must handle it).

const DEFAULT_CAPACITY: int = 512

var capacity: int
var alive_count: int = 0
var high_water: int = 0

var alive: PackedByteArray
var pos_x: PackedFloat32Array
var pos_y: PackedFloat32Array
var vel_x: PackedFloat32Array
var vel_y: PackedFloat32Array
var damage: PackedFloat64Array
var ttl_ticks: PackedInt32Array
## Enemy type index of the shooter.
var owner_type: PackedByteArray

var _free_list: PackedInt32Array
var _free_top: int = 0


func _init(slots: int = DEFAULT_CAPACITY) -> void:
	capacity = slots
	alive = _u8(slots)
	owner_type = _u8(slots)
	pos_x = _f32(slots)
	pos_y = _f32(slots)
	vel_x = _f32(slots)
	vel_y = _f32(slots)
	damage = _f64(slots)
	ttl_ticks = _i32(slots)
	_free_list = _i32(slots)


## Returns a fresh index (fields reset) or -1 if full.
func alloc() -> int:
	var i: int
	if _free_top > 0:
		_free_top -= 1
		i = _free_list[_free_top]
	elif high_water < capacity:
		i = high_water
		high_water += 1
	else:
		return -1
	alive[i] = 1
	owner_type[i] = 0
	pos_x[i] = 0.0
	pos_y[i] = 0.0
	vel_x[i] = 0.0
	vel_y[i] = 0.0
	damage[i] = 0.0
	ttl_ticks[i] = 0
	alive_count += 1
	return i


## Frees an index. Releasing a dead or out-of-range index is a no-op.
func release(i: int) -> void:
	if i < 0 or i >= high_water or alive[i] == 0:
		return
	alive[i] = 0
	alive_count -= 1
	_free_list[_free_top] = i
	_free_top += 1


func is_alive(i: int) -> bool:
	return i >= 0 and i < high_water and alive[i] != 0


static func _u8(n: int) -> PackedByteArray:
	var a: PackedByteArray = PackedByteArray()
	if a.resize(n) != OK:
		push_error("ProjectileStore: resize failed")
	return a


static func _f32(n: int) -> PackedFloat32Array:
	var a: PackedFloat32Array = PackedFloat32Array()
	if a.resize(n) != OK:
		push_error("ProjectileStore: resize failed")
	return a


static func _f64(n: int) -> PackedFloat64Array:
	var a: PackedFloat64Array = PackedFloat64Array()
	if a.resize(n) != OK:
		push_error("ProjectileStore: resize failed")
	return a


static func _i32(n: int) -> PackedInt32Array:
	var a: PackedInt32Array = PackedInt32Array()
	if a.resize(n) != OK:
		push_error("ProjectileStore: resize failed")
	return a
