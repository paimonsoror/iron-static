class_name EnemyRenderer
extends Node2D
## Draws all enemies and bolts with one MultiMeshInstance2D per shape (5 enemy types + bolts =
## 6 draw calls, TECH_ARCHITECTURE 2.6). Pure observer: reads the sim stores in render().
## Local space: origin = Cinder, sim axes scaled by px_per_m (place this node at Cinder's
## screen position; any axis flip is the parent's job).
## Buffers are preallocated at setup(); render() only fills them and uploads once per type.

const ENEMY_SHAPES: Array[String] = ["skitter", "dart", "walker", "lancer", "boss_hulk"]
const STROKE_PX: float = 2.5
## Bolt radius in meters (impl: ProjectileStore has no radius).
const BOLT_RADIUS_M: float = 0.3
const DEFAULT_RADIUS_M: float = 0.5

var _px_per_m: float = 33.75
## Local-pixel rectangle outside which instance centers are skipped (empty = no culling).
var _cull := Rect2()
var _rids: Array[RID] = []  # index 0-4 enemy types, 5 bolts
var _buffers: Array[PackedFloat32Array] = []
var _instances: Array[MultiMeshInstance2D] = []


## `radii_m`: typical radius in meters per enemy type (index order), used only to size outline
## strokes so they render about STROKE_PX wide. The capacities size the preallocated buffers.
func setup(
	px_per_m: float,
	radii_m: PackedFloat32Array,
	enemy_capacity: int = EnemyStore.DEFAULT_CAPACITY,
	bolt_capacity: int = ProjectileStore.DEFAULT_CAPACITY
) -> void:
	_px_per_m = px_per_m
	for inst: MultiMeshInstance2D in _instances:
		inst.queue_free()
	_instances.clear()
	_rids.clear()
	_buffers.clear()
	for t: int in ENEMY_SHAPES.size() + 1:
		var is_bolt: bool = t == ENEMY_SHAPES.size()
		var radius_m: float = BOLT_RADIUS_M if is_bolt else _radius_for(radii_m, t)
		var draw_scale: float = ViewMath.VISUAL_SCALE if is_bolt else ViewMath.type_scale(t)
		var stroke: float = ShapeMeshes.stroke_for(STROKE_PX, radius_m * px_per_m * draw_scale)
		var shape: String = "bolt" if is_bolt else ENEMY_SHAPES[t]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = ShapeMeshes.build(shape, stroke)
		var cap: int = bolt_capacity if is_bolt else enemy_capacity
		mm.instance_count = cap
		mm.visible_instance_count = 0
		var inst := MultiMeshInstance2D.new()
		inst.multimesh = mm
		add_child(inst)
		_instances.append(inst)
		_rids.append(mm.get_rid())
		var buf := PackedFloat32Array()
		if buf.resize(cap * MultiMeshBuffer.FLOATS_PER_INSTANCE) != OK:
			push_error("EnemyRenderer: buffer resize failed")
		_buffers.append(buf)


## Fills and uploads every buffer. `alpha` = accumulator / SimWorld.DT in [0, 1].
func render(world: SimWorld, alpha: float) -> void:
	if _instances.is_empty():
		return
	var a: float = clampf(alpha, 0.0, 1.0)
	for t: int in ENEMY_SHAPES.size():
		var n: int = MultiMeshBuffer.fill(
			world.enemies, t, a, _px_per_m, _buffers[t], ViewMath.type_scale(t), true, _cull
		)
		_upload(t, n)
	var last: int = ENEMY_SHAPES.size()
	var nb: int = MultiMeshBuffer.fill_bolts(
		world.projectiles, a, SimWorld.DT, _px_per_m, BOLT_RADIUS_M, _buffers[last], ViewMath.VISUAL_SCALE, true, _cull
	)
	_upload(last, nb)


func _upload(slot: int, count: int) -> void:
	_instances[slot].multimesh.visible_instance_count = count
	RenderingServer.multimesh_set_buffer(_rids[slot], _buffers[slot])


static func _radius_for(radii_m: PackedFloat32Array, t: int) -> float:
	return radii_m[t] if t < radii_m.size() else DEFAULT_RADIUS_M


## Sets the culling rectangle in local pixels (Rect2() disables). Use `cull_rect_for`.
func set_cull(rect: Rect2) -> void:
	_cull = rect


## Battle rect (local px) grown by the largest sprite radius so nothing pops at the edge.
static func cull_rect_for(battle_rect_local: Rect2, px_per_m: float) -> Rect2:
	var margin: float = 4.0 * px_per_m * ViewMath.VISUAL_SCALE
	return battle_rect_local.grow(margin)
