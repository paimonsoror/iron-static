class_name StyleFrameLayout
extends RefCounted
## Fixed enemy formation for the style frame (pure data, seeded). Positions are pixels relative to Cinder at
## 33.75 px/m (32 m camera) with the art bible 4.1 radial stand-off applied; the scene scales the whole world
## group for the 38 m camera. Types: 0 skitter, 1 dart, 2 walker, 3 lancer.

const PX_PER_M: float = 33.75
const STANDOFF_PX: float = 72.0
const CONTACT_R_M: float = 2.0
const RINGS_M: Array[float] = [3.5, 5.0, 7.0, 9.0, 11.0, 13.0, 15.0, 17.0]
const RELAX_RADIUS: Array[float] = [36.0, 40.0, 72.0, 46.0]
## Visible battle area relative to Cinder (below the top HUD plates, above the bottom panel).
const VIS: Rect2 = Rect2(-495.0, -285.0, 990.0, 890.0)
const BOSS_POS: Array[Vector2] = [Vector2(-290.0, 420.0), Vector2(300.0, -190.0)]
const BOSS_RELAX: float = 130.0

var types: PackedInt32Array = PackedInt32Array()
var pos: PackedVector2Array = PackedVector2Array()
var contact_count: int = 0


## Radial stand-off remap (the one `ViewMath.map_pos` of V1-09): meters to draw radius in px.
static func draw_radius(r_m: float) -> float:
	return r_m * PX_PER_M + STANDOFF_PX * clampf(1.0 - (r_m - 2.0) / 8.0, 0.0, 1.0)


func build(count: int, clumped: bool, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	types.clear()
	pos.clear()
	if count == 4:
		# measurement formation (--sf-shots "measure"): one isolated enemy of each type
		types = PackedInt32Array([0, 1, 2, 3])
		pos = PackedVector2Array([Vector2(-400, 0), Vector2(400, 250), Vector2(-250, -200), Vector2(200, 500)])
		return
	contact_count = mini(12, roundi(float(count) * 0.12))
	for k: int in contact_count:
		var a: float = TAU * (float(k) + rng.randf_range(-0.2, 0.2)) / float(contact_count)
		pos.append(Vector2.from_angle(a) * draw_radius(CONTACT_R_M))
	var centers: PackedVector2Array = PackedVector2Array()
	for c: int in 5:
		centers.append(Vector2.from_angle(TAU * (float(c) + 0.3) / 5.0) * rng.randf_range(5.0, 11.0))
	while pos.size() < count:
		var p: Vector2 = Vector2.ZERO
		for _t: int in 80:
			var m: Vector2 = _sample_m(rng, clumped, centers)
			p = m.normalized() * draw_radius(m.length())
			if VIS.has_point(p):
				break
		pos.append(p)
	_assign_types(count, rng)
	_relax()


func _sample_m(rng: RandomNumberGenerator, clumped: bool, centers: PackedVector2Array) -> Vector2:
	if clumped:
		var c: Vector2 = centers[rng.randi() % centers.size()]
		return c + Vector2(rng.randfn(0.0, 1.7), rng.randfn(0.0, 1.7))
	var r: float = RINGS_M[rng.randi() % RINGS_M.size()] + rng.randfn(0.0, 0.5)
	return Vector2.from_angle(rng.randf() * TAU) * maxf(r, 2.6)


func _assign_types(count: int, rng: RandomNumberGenerator) -> void:
	types.resize(count)
	types.fill(0)
	var idx: Array[int] = []
	for i: int in range(contact_count, count):
		idx.append(i)
	var radii: PackedFloat32Array = PackedFloat32Array()
	for p: Vector2 in pos:
		radii.append(p.length())
	idx.sort_custom(func(a: int, b: int) -> bool: return radii[a] > radii[b])
	var n_lancer: int = roundi(float(count) * 0.15)
	var n_walker: int = maxi(3, roundi(float(count) * 0.07))
	var n_dart: int = roundi(float(count) * 0.20)
	for k: int in mini(n_lancer, idx.size()):
		types[idx[k]] = 3
	var rest: Array[int] = idx.slice(n_lancer)
	var from_i: int = floori(float(rest.size()) * 0.3)
	var to_i: int = floori(float(rest.size()) * 0.75)
	var mid: Array[int] = rest.slice(from_i, to_i)
	_shuffle(mid, rng)
	for k: int in mini(n_walker, mid.size()):
		types[mid[k]] = 2
	_shuffle(rest, rng)
	var placed: int = 0
	for i: int in rest:
		if placed >= n_dart:
			break
		if types[i] == 0:
			types[i] = 1
			placed += 1


func _shuffle(a: Array[int], rng: RandomNumberGenerator) -> void:
	for i: int in range(a.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var t: int = a[i]
		a[i] = a[j]
		a[j] = t


func _relax() -> void:
	var n: int = pos.size()
	var f: float = 0.8 if n < 100 else 0.6
	var contact_r: float = draw_radius(CONTACT_R_M)
	for _pass: int in 14:
		for i: int in n:
			for b: int in BOSS_POS.size():
				_push(i, BOSS_POS[b], (RELAX_RADIUS[types[i]] + BOSS_RELAX) * 0.8, 1.0)
			for j: int in range(i + 1, n):
				var need: float = (RELAX_RADIUS[types[i]] + RELAX_RADIUS[types[j]]) * f
				var d: Vector2 = pos[i] - pos[j]
				var dist: float = d.length()
				if dist < need and dist > 0.01:
					var push: Vector2 = d / dist * ((need - dist) * 0.5)
					pos[i] += push
					pos[j] -= push
		for i: int in n:
			if i < contact_count:
				pos[i] = pos[i].normalized() * contact_r
			else:
				var q: Vector2 = pos[i]
				var minr: float = contact_r + 40.0
				if q.length() < minr:
					q = q.normalized() * minr
				pos[i] = Vector2(clampf(q.x, VIS.position.x, VIS.end.x), clampf(q.y, VIS.position.y, VIS.end.y))


func _push(i: int, obstacle: Vector2, need: float, weight: float) -> void:
	var d: Vector2 = pos[i] - obstacle
	var dist: float = d.length()
	if dist < need and dist > 0.01:
		pos[i] += d / dist * ((need - dist) * weight)
