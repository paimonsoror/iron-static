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


## Snapshot support (M3-09): every array up to `high_water`, plus the free list.
func save_state() -> Dictionary:
	var n: int = high_water
	return {
		"alive_count": alive_count,
		"high_water": n,
		"free_top": _free_top,
		"free_list": _free_list.slice(0, _free_top),
		"alive": alive.slice(0, n),
		"owner_type": owner_type.slice(0, n),
		"pos_x": pos_x.slice(0, n),
		"pos_y": pos_y.slice(0, n),
		"vel_x": vel_x.slice(0, n),
		"vel_y": vel_y.slice(0, n),
		"damage": damage.slice(0, n),
		"ttl_ticks": ttl_ticks.slice(0, n),
	}


## Restores `save_state` output into this (fresh) store. Returns false when it does not fit.
func load_state(d: Dictionary) -> bool:
	var n: int = d["high_water"]
	var top: int = d["free_top"]
	if n > capacity or top > capacity:
		return false
	alive_count = d["alive_count"]
	high_water = n
	_free_top = top
	_free_list = EnemyStore._fit_i32(d["free_list"], capacity)
	alive = EnemyStore._fit_u8(d["alive"], capacity)
	owner_type = EnemyStore._fit_u8(d["owner_type"], capacity)
	pos_x = EnemyStore._fit_f32(d["pos_x"], capacity)
	pos_y = EnemyStore._fit_f32(d["pos_y"], capacity)
	vel_x = EnemyStore._fit_f32(d["vel_x"], capacity)
	vel_y = EnemyStore._fit_f32(d["vel_y"], capacity)
	damage = EnemyStore._fit_f64(d["damage"], capacity)
	ttl_ticks = EnemyStore._fit_i32(d["ttl_ticks"], capacity)
	return true
