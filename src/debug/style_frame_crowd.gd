class_name StyleFrameCrowd
extends Node2D
## Enemies (one MultiMesh per type with the enemy shader), 2 bosses and 12 bolts for the style frame.
## Origin = Cinder, pixels at 33.75 px/m (the parent scales for other cameras). Draw order: enemies, bosses,
## bolts. Frame animation and hit flash are written to INSTANCE_CUSTOM (x flash, y frame, z spawn, w phase).

## slot, cell (texels), frames, pivot (texels), fps, flash cap
const SLOTS: Array[String] = ["skitter", "dart", "walker", "lancer"]
const CELLS: Array[Vector2] = [Vector2(192, 192), Vector2(256, 160), Vector2(384, 384), Vector2(288, 224)]
const FRAMES: Array[int] = [4, 4, 4, 3]
const PIVOTS: Array[Vector2] = [Vector2(96, 96), Vector2(112, 80), Vector2(192, 192), Vector2(112, 112)]
const FPS: Array[float] = [8.0, 14.0, 5.0, 0.0]
const FLASH_CAP: Array[float] = [1.0, 1.0, 0.6, 1.0]
const FLASH_PERIOD_S: float = 0.9
const FLASH_LEN_S: float = 0.09
const BOLT_COUNT: int = 12

var layout: StyleFrameLayout = StyleFrameLayout.new()
var bolt_positions: PackedVector2Array = PackedVector2Array()
var _mms: Array[MultiMesh] = []
var _mats: Array[ShaderMaterial] = []
var _idx: Array[PackedInt32Array] = []  # per type: layout indices
var _bosses: Array[Sprite2D] = []
var _boss_mat: ShaderMaterial = null
var _bolt_mm: MultiMesh = null
var _bolt_mat: ShaderMaterial = null
var _t: float = 0.0
var _last_slot: int = -1


func _ready() -> void:
	for t: int in SLOTS.size():
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_custom_data = true
		mm.mesh = StyleFrameArt.quad_mesh(CELLS[t] * 0.5, PIVOTS[t] * 0.5)
		var mat: ShaderMaterial = StyleFrameArt.enemy_material(SLOTS[t] + "_glow", FRAMES[t], 1)
		mat.set_shader_parameter("use_instance_custom", true)
		mat.set_shader_parameter("flash_cap", FLASH_CAP[t])
		var inst := MultiMeshInstance2D.new()
		inst.multimesh = mm
		inst.texture = StyleFrameArt.tex(SLOTS[t])
		inst.material = mat
		inst.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(inst)
		_mms.append(mm)
		_mats.append(mat)
		_idx.append(PackedInt32Array())
	_build_bosses()
	_build_bolts()


func _build_bosses() -> void:
	_boss_mat = StyleFrameArt.enemy_material("boss_hulk_glow", 1, 4)
	_boss_mat.set_shader_parameter("flash_cap", 0.6)
	_boss_mat.set_shader_parameter("pulse_hz", 0.83)
	for b: int in StyleFrameLayout.BOSS_POS.size():
		var s: Sprite2D = StyleFrameArt.sprite_c(
			self, StyleFrameArt.tex("boss_hulk"), Rect2(0, 0, 640, 640), 2.0 / 3.0, false
		)
		s.material = _boss_mat
		s.position = StyleFrameLayout.BOSS_POS[b]
		s.rotation = (-s.position).angle()
		_bosses.append(s)


func _build_bolts() -> void:
	_bolt_mm = MultiMesh.new()
	_bolt_mm.transform_format = MultiMesh.TRANSFORM_2D
	_bolt_mm.use_custom_data = true
	_bolt_mm.mesh = StyleFrameArt.quad_mesh(Vector2(64, 32), Vector2(28, 16))
	_bolt_mat = StyleFrameArt.enemy_material("bolt_glow", 2, 1)
	_bolt_mat.set_shader_parameter("use_instance_custom", true)
	var inst := MultiMeshInstance2D.new()
	inst.multimesh = _bolt_mm
	inst.texture = StyleFrameArt.tex("bolt")
	inst.material = _bolt_mat
	inst.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(inst)


## Rebuilds the formation (density, ring or clumped).
func set_formation(count: int, clumped: bool) -> void:
	layout.build(count, clumped, 7)
	for t: int in SLOTS.size():
		_idx[t] = PackedInt32Array()
	for i: int in layout.types.size():
		var t: int = layout.types[i]
		var a: PackedInt32Array = _idx[t]
		a.append(i)
		_idx[t] = a
	for t: int in SLOTS.size():
		var mm: MultiMesh = _mms[t]
		mm.instance_count = _idx[t].size()
		for k: int in _idx[t].size():
			var p: Vector2 = layout.pos[_idx[t][k]]
			mm.set_instance_transform_2d(k, Transform2D((-p).angle(), p))
	_place_bolts()
	_last_slot = -1
	_animate(true)


func _place_bolts() -> void:
	bolt_positions.clear()
	_bolt_mm.instance_count = BOLT_COUNT
	var lancers: PackedInt32Array = _idx[3]
	for b: int in BOLT_COUNT:
		var src: Vector2 = Vector2.from_angle(float(b) * 0.9) * 420.0
		if lancers.size() > 0:
			src = layout.pos[lancers[b % lancers.size()]]
		var t: float = 0.3 + 0.55 * fmod(float(b) * 0.37, 1.0)
		var p: Vector2 = src.lerp(Vector2.ZERO, t)
		var jitter: Vector2 = Vector2.from_angle(float(b) * 2.3) * float(b % 3) * 14.0
		p += jitter
		bolt_positions.append(p)
		_bolt_mm.set_instance_transform_2d(b, Transform2D((-p).angle(), p))


func set_glow(on: bool) -> void:
	var g: float = 1.0 if on else 0.0
	for m: ShaderMaterial in _mats:
		m.set_shader_parameter("glow_strength", g)
	_boss_mat.set_shader_parameter("glow_strength", g)
	_bolt_mat.set_shader_parameter("glow_strength", g)


func _process(delta: float) -> void:
	_t += delta
	_boss_mat.set_shader_parameter("flash", _flash_at(0.2))
	_animate(false)


func _flash_at(phase: float) -> float:
	var p: float = fmod(_t + phase, FLASH_PERIOD_S)
	return clampf(1.0 - p / FLASH_LEN_S, 0.0, 1.0)


func _animate(force: bool) -> void:
	var slot: int = floori(_t * 24.0)
	var frame_tick: bool = slot != _last_slot or force
	_last_slot = slot
	for t: int in SLOTS.size():
		var ids: PackedInt32Array = _idx[t]
		var mm: MultiMesh = _mms[t]
		for k: int in ids.size():
			var flash: bool = k < 3
			if not (frame_tick or flash):
				continue
			var phase: float = float(ids[k] % 17) * 0.37
			var f: float = 0.0
			if t == 3:
				f = float(ids[k] % 3) if ids[k] % 5 == 0 else 0.0
			else:
				f = floorf(_t * FPS[t] + phase)
			var fl: float = _flash_at(float(k) * 0.31 + float(t) * 0.17) if flash else 0.0
			mm.set_instance_custom_data(k, Color(fl, f, 1.0, phase))
	if not frame_tick:
		return
	for b: int in BOLT_COUNT:
		_bolt_mm.set_instance_custom_data(b, Color(0.0, floorf(_t * 12.0 + float(b)), 1.0, float(b) * 0.3))
	for s: Sprite2D in _bosses:
		_boss_mat.set_shader_parameter("frame", floorf(_t * 6.0))
		s.modulate = Color.WHITE
