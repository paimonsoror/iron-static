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


## Snapshot support (M3-09): every array up to `high_water`, plus the free list and counters.
func save_state() -> Dictionary:
	var n: int = high_water
	return {
		"alive_count": alive_count,
		"high_water": n,
		"free_top": _free_top,
		"next_spawn_id": _next_spawn_id,
		"type_counts": _type_counts.duplicate(),
		"free_list": _free_list.slice(0, _free_top),
		"alive": alive.slice(0, n),
		"stale": stale.slice(0, n),
		"type_id": type_id.slice(0, n),
		"pos_x": pos_x.slice(0, n),
		"pos_y": pos_y.slice(0, n),
		"prev_x": prev_x.slice(0, n),
		"prev_y": prev_y.slice(0, n),
		"radius": radius.slice(0, n),
		"speed": speed.slice(0, n),
		"hp": hp.slice(0, n),
		"max_hp": max_hp.slice(0, n),
		"dmg": dmg.slice(0, n),
		"spawn_id": spawn_id.slice(0, n),
		"born_wave": born_wave.slice(0, n),
		"level_hp": level_hp.slice(0, n),
		"melee_hits": melee_hits.slice(0, n),
		"next_attack_tick": next_attack_tick.slice(0, n),
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
	_next_spawn_id = d["next_spawn_id"]
	_type_counts = d["type_counts"]
	_free_list = _fit_i32(d["free_list"], capacity)
	alive = _fit_u8(d["alive"], capacity)
	stale = _fit_u8(d["stale"], capacity)
	type_id = _fit_u8(d["type_id"], capacity)
	pos_x = _fit_f32(d["pos_x"], capacity)
	pos_y = _fit_f32(d["pos_y"], capacity)
	prev_x = _fit_f32(d["prev_x"], capacity)
	prev_y = _fit_f32(d["prev_y"], capacity)
	radius = _fit_f32(d["radius"], capacity)
	speed = _fit_f32(d["speed"], capacity)
	hp = _fit_f64(d["hp"], capacity)
	max_hp = _fit_f64(d["max_hp"], capacity)
	dmg = _fit_f64(d["dmg"], capacity)
	spawn_id = _fit_i32(d["spawn_id"], capacity)
	born_wave = _fit_i32(d["born_wave"], capacity)
	level_hp = _fit_i32(d["level_hp"], capacity)
	melee_hits = _fit_i32(d["melee_hits"], capacity)
	next_attack_tick = _fit_i32(d["next_attack_tick"], capacity)
	cell = _i32(capacity)
	cell.fill(-1)  # derived: the grid rebuild writes it for every alive enemy
	return true


static func _fit_u8(src: Variant, n: int) -> PackedByteArray:
	var loaded: PackedByteArray = src
	var a: PackedByteArray = loaded.duplicate()
	if a.resize(n) != OK:
		push_error("EnemyStore: resize failed")
	return a


static func _fit_f32(src: Variant, n: int) -> PackedFloat32Array:
	var loaded: PackedFloat32Array = src
	var a: PackedFloat32Array = loaded.duplicate()
	if a.resize(n) != OK:
		push_error("EnemyStore: resize failed")
	return a


static func _fit_f64(src: Variant, n: int) -> PackedFloat64Array:
	var loaded: PackedFloat64Array = src
	var a: PackedFloat64Array = loaded.duplicate()
	if a.resize(n) != OK:
		push_error("EnemyStore: resize failed")
	return a


static func _fit_i32(src: Variant, n: int) -> PackedInt32Array:
	var loaded: PackedInt32Array = src
	var a: PackedInt32Array = loaded.duplicate()
	if a.resize(n) != OK:
		push_error("EnemyStore: resize failed")
	return a
