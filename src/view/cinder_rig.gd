class_name CinderRig
extends RefCounted
## State and painters of the layered Cinder rig (V1-11, art bible 4.2, 4.5, 6.5). `CinderView` owns one rig and two
## canvas layers; the layers call `paint_body` (normal blend, `cinder` sheet) and `paint_glow` (additive,
## `cinder_glow` sheet). Every draw is `draw_texture_rect_region` on one of two textures, so each layer is one
## batch. Cell rects and pivots come from `ArtSlots`; placement math is in `CinderLayout`, curves in `CinderAnim`.
## No allocation per frame (state lives in packed arrays); never touches the sim.

const WEDGES: int = CinderWedges.WEDGE_COUNT
const KIND_NONE: int = 0
## Entered a worse state: gone = detach and fade, charred = crossfade intact to charred.
const KIND_DOWN: int = 1
## Recovering: the wedge re-forms at its slot of the 12-step schedule.
const KIND_UP: int = 2
const FLASH_TEAL := Color(0.75, 1.0, 0.96)

var scale_f: float = 1.0
## 0 = glow sheets off (tier), else the glow alpha multiplier.
var glow_mul: float = 1.0
## No idle pulse or flicker, no shiver.
var reduce_motion: bool = false
## False = band changes snap (LOW tier).
var animate: bool = true
var band: int = 0
var aim: float = -PI * 0.5
var time_s: float = 0.0
var ring_rot: float = 0.0
var visor_rot: float = 0.0
var states: PackedInt32Array = CinderWedges.states(0)

var _kind := PackedInt32Array()
var _from := PackedInt32Array()
var _t0 := PackedFloat64Array()
var _started: bool = false
var _hit_at: float = -10.0
var _shot_at: float = -10.0
var _shiver_seed: int = 0
var _pulse: float = 0.5
var _body: Texture2D = null
var _glow: Texture2D = null


func _init() -> void:
	_kind.resize(WEDGES)
	_from.resize(WEDGES)
	_t0.resize(WEDGES)


## Advances the rig to the latest sim values (view clock `t`).
## `beat_t` >= 0 is the band-3 heartbeat clock (the overlay's), so core and haze beat together.
func update(new_band: int, new_aim: float, t: float, beat_t: float = -1.0) -> void:
	var dt: float = clampf(t - time_s, 0.0, 0.05) if _started else 0.0
	time_s = t
	aim = new_aim
	if not _started:
		ring_rot = CinderLayout.ring_rotation_for(aim, 0)
		visor_rot = aim + CinderLayout.UP_OFFSET
		band = new_band
		states = CinderWedges.states(band)
		_started = true
	elif new_band != band:
		_begin_transition(new_band)
	ring_rot = CinderAnim.aim_step(ring_rot, CinderLayout.ring_target(ring_rot, aim), dt)
	visor_rot = CinderAnim.aim_step(visor_rot, aim + CinderLayout.UP_OFFSET, dt)
	_pulse = 0.5 if reduce_motion else CinderAnim.pulse(band, t if beat_t < 0.0 else beat_t)
	if reduce_motion and band >= 3:
		_pulse = 0.7
	_finish_transitions()


func notify_hit() -> void:
	_hit_at = time_s
	_shiver_seed += 1


func notify_shot() -> void:
	_shot_at = time_s


## Offset of the whole rig after a hit (zero outside the 100 ms window and under reduce motion).
func shiver() -> Vector2:
	if reduce_motion:
		return Vector2.ZERO
	return CinderAnim.shiver_offset(time_s - _hit_at, _shiver_seed) * scale_f


func active_node() -> int:
	return CinderLayout.active_node(ring_rot, aim)


## Position of the active emitter node relative to the Cinder origin (px).
func emitter_position() -> Vector2:
	return CinderLayout.node_position(ring_rot, active_node(), scale_f)


## Transition kind of wedge `k` (KIND_NONE, KIND_DOWN, KIND_UP).
func kind_of(k: int) -> int:
	return _kind[k]


## True while any wedge transition is running.
func animating() -> bool:
	for k: int in WEDGES:
		if _kind[k] != KIND_NONE:
			return true
	return false


func _begin_transition(new_band: int) -> void:
	var old_states: PackedInt32Array = states
	states = CinderWedges.states(new_band)
	band = new_band
	for k: int in WEDGES:
		if old_states[k] == states[k] or not animate:
			_kind[k] = KIND_NONE
			continue
		_from[k] = old_states[k]
		if states[k] > old_states[k]:
			_kind[k] = KIND_DOWN
			_t0[k] = time_s
		else:
			_kind[k] = KIND_UP
			_t0[k] = time_s + CinderAnim.reform_start(k)


func _finish_transitions() -> void:
	for k: int in WEDGES:
		var el: float = time_s - _t0[k]
		match _kind[k]:
			KIND_DOWN:
				var dur: float = CinderAnim.DETACH_S if states[k] == CinderWedges.GONE else CinderAnim.CHAR_S
				if el >= dur:
					_kind[k] = KIND_NONE
			KIND_UP:
				if el >= CinderAnim.REFORM_STEP_S:
					_kind[k] = KIND_NONE


func _tex(art: ArtSlot) -> Texture2D:
	if _body == null:
		_body = ArtSlots.texture(CinderLayout.SLOT_FRAME)
		_glow = ArtSlots.texture(CinderLayout.SLOT_FRAME_HOT)
	return _glow if art.additive else _body


## One cell with its pivot on `pos`, rotated by `rot`, scaled by `sc` on top of the rig scale.
func _cell(c: CanvasItem, slot_id: String, pos: Vector2, rot: float, sc: float, mod: Color) -> void:
	if slot_id.is_empty():
		return
	var art: ArtSlot = ArtSlots.slot(slot_id)
	var ppt: float = CinderLayout.GLOW_PX_PER_TEXEL if art.additive else CinderLayout.BODY_PX_PER_TEXEL
	c.draw_set_transform(pos, rot, Vector2(sc, sc))
	var rect: Rect2 = CinderLayout.cell_draw_rect(art.pivot, Vector2(art.cell_size), ppt * scale_f)
	c.draw_texture_rect_region(_tex(art), rect, art.frame_rect(0), mod)


func _gray(v: float, a: float = 1.0) -> Color:
	return Color(v, v, v, a)


func paint_body(c: CanvasItem) -> void:
	var s: float = scale_f
	_cell(
		c, CinderLayout.SLOT_SHADOW, CinderLayout.SHADOW_OFFSET * s, 0.0, CinderLayout.SHADOW_SCALE / 0.5, Color.WHITE
	)
	_cell(c, CinderLayout.SLOT_FRAME, Vector2.ZERO, 0.0, 1.0, Color.WHITE)
	_paint_wedges(c, false, false)
	_cell(c, CinderLayout.SLOT_HOUSING, Vector2.ZERO, 0.0, 1.0, Color.WHITE)
	var boost: float = CinderAnim.hit_boost(time_s - _hit_at)
	var core_v: float = 0.9 + 0.1 * _pulse + boost
	_cell(c, CinderLayout.core_slot(band), Vector2.ZERO, 0.0, 1.0 + 0.08 * _pulse, _gray(core_v))
	if CinderLayout.has_crack(band):
		_cell(c, CinderLayout.SLOT_CRACK, Vector2.ZERO, 0.0, 1.0, Color.WHITE)
	_cell(c, CinderLayout.SLOT_RING, Vector2.ZERO, ring_rot, 1.0, Color.WHITE)
	_cell(c, CinderLayout.SLOT_VISOR, Vector2.ZERO, visor_rot, 1.0, Color.WHITE)
	_cell(c, CinderLayout.SLOT_SHOULDER, CinderLayout.SHOULDER_POS * s, 0.0, 1.0, Color.WHITE)
	_cell(c, CinderLayout.SLOT_TICKS, CinderLayout.TICKS_POS * s, 0.0, CinderLayout.TICKS_SCALE, Color.WHITE)
	_paint_wedges(c, false, true)


func paint_glow(c: CanvasItem) -> void:
	var s: float = scale_f
	var g: float = glow_mul
	if g <= 0.0:
		return
	var boost: float = CinderAnim.hit_boost(time_s - _hit_at)
	if CinderLayout.has_frame_hot(band):
		_cell(c, CinderLayout.SLOT_FRAME_HOT, Vector2.ZERO, 0.0, 1.0, _white_a((0.65 + 0.35 * _pulse) * g))
	_paint_wedges(c, true, false)
	var halo_a: float = 0.45 + 0.12 * _pulse + boost
	if band >= 3:
		halo_a = 0.45 + 0.3 * _pulse
	elif band == 2:
		halo_a += 0.08
	_cell(c, CinderLayout.core_halo_slot(band), Vector2.ZERO, 0.0, 1.0, _white_a(halo_a * g))
	if CinderLayout.has_crack(band):
		_cell(c, CinderLayout.SLOT_CRACK_GLOW, Vector2.ZERO, 0.0, 1.0, _white_a(g))
	var shot: float = CinderAnim.shot_boost(time_s - _shot_at)
	_cell(c, CinderLayout.SLOT_RING_GLOW, Vector2.ZERO, ring_rot, 1.0, _white_a((1.0 + 0.8 * shot) * g))
	_cell(c, CinderLayout.SLOT_VISOR_GLOW, Vector2.ZERO, visor_rot, 1.0, _white_a(g))
	var lens: Vector2 = (CinderLayout.SHOULDER_POS + CinderLayout.SHOULDER_LENS_OFFSET) * s
	_cell(c, CinderLayout.SLOT_SHOULDER_GLOW, lens, 0.0, 1.0, _white_a((0.9 + 0.6 * shot) * g))
	_cell(c, CinderLayout.SLOT_TICKS_GLOW, CinderLayout.TICKS_POS * s, 0.0, CinderLayout.TICKS_SCALE, _white_a(0.8 * g))
	_paint_wedges(c, true, true)


func _white_a(a: float) -> Color:
	return Color(1.0, 1.0, 1.0, a)


## Static wedges (`flying` false) or the transitioning ones that sit above the ring (`flying` true).
func _paint_wedges(c: CanvasItem, glow: bool, flying: bool) -> void:
	var flick: float = 0.85 if reduce_motion else CinderAnim.ember_flicker(band, time_s)
	for k: int in WEDGES:
		var kind: int = _kind[k]
		var cur: int = states[k]
		var el: float = time_s - _t0[k]
		var detaching: bool = kind == KIND_DOWN and cur == CinderWedges.GONE
		if detaching != flying:
			continue
		if kind == KIND_NONE:
			_wedge(c, glow, k, cur, Vector2.ZERO, 0.0, 1.0, 1.0, flick)
		elif detaching:
			var out: Vector2 = Vector2.from_angle(CinderLayout.wedge_rotation(k) - PI * 0.5)
			var pos: Vector2 = out * CinderAnim.detach_offset(k, el) * scale_f
			var a: float = CinderAnim.detach_alpha(el)
			_wedge(c, glow, k, _from[k], pos, CinderAnim.detach_spin(k, el), CinderAnim.detach_scale(el), a, flick)
		elif kind == KIND_DOWN:
			# intact to charred: charred below, the intact plate fades out above it
			_wedge(c, glow, k, cur, Vector2.ZERO, 0.0, 1.0, 1.0, flick)
			_wedge(c, glow, k, _from[k], Vector2.ZERO, 0.0, 1.0, 1.0 - el / CinderAnim.CHAR_S, flick)
		elif el < 0.0:
			_wedge(c, glow, k, _from[k], Vector2.ZERO, 0.0, 1.0, 1.0, flick)
		else:
			var u: float = clampf(el / CinderAnim.REFORM_STEP_S, 0.0, 1.0)
			_wedge(c, glow, k, cur, Vector2.ZERO, 0.0, CinderAnim.reform_scale(el), u, flick)


func _wedge(
	c: CanvasItem, glow: bool, k: int, state: int, pos: Vector2, spin: float, sc: float, alpha: float, flick: float
) -> void:
	var id: String = CinderLayout.wedge_glow_slot(k, state) if glow else CinderLayout.wedge_slot(k, state)
	if id.is_empty():
		return
	var a: float = alpha
	if glow:
		a *= glow_mul * (flick if state == CinderWedges.CHARRED else 1.0)
	var mod: Color = Color(1.0, 1.0, 1.0, a)
	if glow and _kind[k] == KIND_UP and state == states[k]:
		var f: float = CinderAnim.reform_flash(time_s - _t0[k])
		if f > 0.0:
			mod = FLASH_TEAL
			mod.a = a
	_cell(c, id, pos, CinderLayout.wedge_rotation(k) + spin, sc, mod)
