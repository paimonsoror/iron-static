class_name EnemyStore
extends RefCounted
## Struct-of-arrays enemy store with a free list (TECH_ARCHITECTURE 2.4).
##
## All arrays are sized to `capacity` at construction and never resized, so
## `alloc`/`release` never allocate. Loops over the store must be bounded by
## `high_water` and skip entries where `alive[i] == 0`.
## `type_id` is set by `alloc(type)`; do not change it afterwards, because
## `count_type` is maintained from it on alloc/release.

const DEFAULT_CAPACITY: int = 512
const MAX_TYPES: int = 16

var capacity: int
var alive_count: int = 0
## Highest index ever used + 1. Bounds every loop over the arrays.
var high_water: int = 0

var alive: PackedByteArray
var stale: PackedByteArray
var type_id: PackedByteArray
var pos_x: PackedFloat32Array
var pos_y: PackedFloat32Array
var prev_x: PackedFloat32Array
var prev_y: PackedFloat32Array
var radius: PackedFloat32Array
var speed: PackedFloat32Array
var hp: PackedFloat64Array
var max_hp: PackedFloat64Array
var dmg: PackedFloat64Array
var spawn_id: PackedInt32Array
var born_wave: PackedInt32Array
var level_hp: PackedInt32Array
## Spatial grid cell, written by `SpatialGrid.rebuild`; -1 when not placed.
var cell: PackedInt32Array
var melee_hits: PackedInt32Array
var next_attack_tick: PackedInt32Array

var _free_list: PackedInt32Array
var _free_top: int = 0
var _next_spawn_id: int = 0
var _type_counts: PackedInt32Array


func _init(slots: int = DEFAULT_CAPACITY) -> void:
	capacity = slots
	alive = _u8(slots)
	stale = _u8(slots)
	type_id = _u8(slots)
	pos_x = _f32(slots)
	pos_y = _f32(slots)
	prev_x = _f32(slots)
	prev_y = _f32(slots)
	radius = _f32(slots)
	speed = _f32(slots)
	hp = _f64(slots)
	max_hp = _f64(slots)
	dmg = _f64(slots)
	spawn_id = _i32(slots)
	born_wave = _i32(slots)
	level_hp = _i32(slots)
	cell = _i32(slots)
	melee_hits = _i32(slots)
	next_attack_tick = _i32(slots)
	_free_list = _i32(slots)
	_type_counts = _i32(MAX_TYPES)


## Returns a fresh index (all fields reset, `spawn_id` assigned) or -1 if full.
## Freed indices are reused LIFO before `high_water` grows.
func alloc(type: int = 0) -> int:
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
	stale[i] = 0
	type_id[i] = type
	pos_x[i] = 0.0
	pos_y[i] = 0.0
	prev_x[i] = 0.0
	prev_y[i] = 0.0
	radius[i] = 0.0
	speed[i] = 0.0
	hp[i] = 0.0
	max_hp[i] = 0.0
	dmg[i] = 0.0
	spawn_id[i] = _next_spawn_id
	_next_spawn_id += 1
	born_wave[i] = 0
	level_hp[i] = 0
	cell[i] = -1
	melee_hits[i] = 0
	next_attack_tick[i] = 0
	alive_count += 1
	_type_counts[type] += 1
	return i


## Frees an index. Releasing a dead or out-of-range index is a no-op.
func release(i: int) -> void:
	if i < 0 or i >= high_water or alive[i] == 0:
		return
	alive[i] = 0
	alive_count -= 1
	_type_counts[type_id[i]] -= 1
	_free_list[_free_top] = i
	_free_top += 1


func is_alive(i: int) -> bool:
	return i >= 0 and i < high_water and alive[i] != 0


## Alive enemies of enemy type index `t` (maintained incrementally).
func count_type(t: int) -> int:
	if t < 0 or t >= MAX_TYPES:
		return 0
	return _type_counts[t]


static func _u8(n: int) -> PackedByteArray:
	var a: PackedByteArray = PackedByteArray()
	if a.resize(n) != OK:
		push_error("EnemyStore: resize failed")
	return a


static func _f32(n: int) -> PackedFloat32Array:
	var a: PackedFloat32Array = PackedFloat32Array()
	if a.resize(n) != OK:
		push_error("EnemyStore: resize failed")
	return a


static func _f64(n: int) -> PackedFloat64Array:
	var a: PackedFloat64Array = PackedFloat64Array()
	if a.resize(n) != OK:
		push_error("EnemyStore: resize failed")
	return a


static func _i32(n: int) -> PackedInt32Array:
	var a: PackedInt32Array = PackedInt32Array()
	if a.resize(n) != OK:
		push_error("EnemyStore: resize failed")
	return a
