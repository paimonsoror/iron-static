class_name BeamRenderer
extends Node2D
## Hitscan beams (GDD 02 section 2, GDD 07 section 5.1/5.3, art bible 6.1): on each SHOT_FIRED event a beam
## from the active emitter node to the target's near hull edge is stored in a fixed pool of 16 and fades over
## 80 ms of wall time. Each beam is three stretched quads of the uniform `fx_beam_strip` texture (glow 36 px,
## core 8 px, hot center 3 px, widths x1.5 on a crit) plus `fx_beam_cap` end caps, a muzzle flare and cone at
## the emitter and a crit flare at the target. All quads share one texture and an additive material, so they
## batch into one or two draw calls. Above 8 shots/s consecutive beams to the same end merge into one
## sustained, pulsing beam instead of filling the pool. Hit sparks come from FxSpawner (ENEMY_HIT), never here.
## Local space: origin = Cinder, sim meters * px_per_m (same convention as EnemyRenderer).
##
## Target position: read from the enemy store when the event is drained. Released slots keep
## their last position (the store never clears it), so a target killed by its own shot still
## gets a correct end point. Only if the slot was reused by a new spawn within the same frame
## (needs several ticks per frame) would the end be wrong; accepted for M1 (impl).

const MAX_BEAMS: int = 16
const FADE_S: float = BeamMath.FADE_S
## Fraction of the target sprite radius the beam is pulled back (art bible 4.1).
const BEAM_PULLBACK: float = 0.6
const RATE_RING: int = 16

## Optional: reduce motion switches off jitter, wobble and the flare scale animation.
var visual: VisualSettings

var _start := PackedVector2Array()
var _end := PackedVector2Array()
var _born := PackedFloat32Array()
var _width_mul := PackedFloat32Array()
var _crit := PackedByteArray()
var _merged := PackedByteArray()
var _times := PackedFloat64Array()
var _next: int = 0
var _last: int = -1
var _shot_counter: int = 0
var _rate_next: int = 0
var _now_s: float = 0.0
var _events := EventCursor.new()
var _was_active: bool = false
var _sheet: Texture2D
var _strip: Rect2
var _cap: Rect2
var _flare4: Rect2
var _flare8: Rect2
var _cone: Rect2
var _cone_pivot_x: float = 0.0


func _init() -> void:
	var ok: bool = _start.resize(MAX_BEAMS) == OK
	ok = ok and _end.resize(MAX_BEAMS) == OK
	ok = ok and _born.resize(MAX_BEAMS) == OK
	ok = ok and _width_mul.resize(MAX_BEAMS) == OK
	ok = ok and _crit.resize(MAX_BEAMS) == OK
	ok = ok and _merged.resize(MAX_BEAMS) == OK
	ok = ok and _times.resize(RATE_RING) == OK
	if not ok:
		push_error("BeamRenderer: resize failed")
	for i: int in MAX_BEAMS:
		_born[i] = -1000.0
		_width_mul[i] = 1.0
	for i: int in RATE_RING:
		_times[i] = -1000.0
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	# Plain linear, no mipmaps: the fx sheet imports with mipmaps for particles, the 3 px core must stay crisp.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


## Events skipped because the ring wrapped past this reader (debug overlay).
func events_lost_total() -> int:
	return _events.lost_total


## Call when binding to a world mid-run so old events are not drawn.
func bind(world: SimWorld) -> void:
	_events.sync_to(world.events)


## Consumes new SHOT_FIRED events and redraws. `now_s` is monotonic wall time (seconds),
## `emitter_px` the beam start in local pixels, `enemies` supplies the per-type stand-off (null = default).
func update(world: SimWorld, now_s: float, px_per_m: float, emitter_px: Vector2, enemies: EnemyRenderer = null) -> void:
	_now_s = now_s
	var store: EnemyStore = world.enemies
	while _events.poll(world.events) > 0:
		for i: int in _events.count:
			if _events.kind_at(i) != SimEventKind.SHOT_FIRED:
				continue
			var idx: int = _events.a_at(i)
			if idx < 0 or idx >= store.high_water:
				continue
			var type: int = store.type_id[idx]
			var vis_r: float = ViewMath.visual_radius_px(store.radius[idx], type, px_per_m)
			var standoff: float = ViewMath.STANDOFF_PX if enemies == null else enemies.standoff_px(type)
			var target: Vector2 = beam_end(Vector2(store.pos_x[idx], store.pos_y[idx]), vis_r, px_per_m, standoff)
			shoot(emitter_px, target, now_s, _events.b_at(i) != 0)
	var active: bool = _any_active()
	if active or _was_active:
		queue_redraw()
	_was_active = active


## Registers one shot: adds a beam to the ring (overwrites the oldest when 16 are in use) or, at more than
## 8 shots/s, refreshes the previous beam when it ends within 8 px of the new end (sustained beam).
func shoot(start: Vector2, end: Vector2, now_s: float, crit: bool = false) -> void:
	_times[_rate_next] = now_s
	_rate_next = (_rate_next + 1) % RATE_RING
	var calm: bool = visual != null and visual.reduce_motion
	var jit: Vector2 = Vector2(1.0, 0.0) if calm else BeamMath.jitter(_shot_counter)
	_shot_counter += 1
	var dir: Vector2 = (end - start).normalized()
	var wobbled: Vector2 = end + dir.orthogonal() * jit.y
	var slot: int = _next
	var merge: bool = false
	if _last >= 0 and BeamMath.should_merge(BeamMath.shots_in_window(_times, now_s)):
		var age: float = now_s - _born[_last]
		# Eligible up to 2 x FADE_S: at 8 to 12 shots/s the previous plain beam has just expired (impl).
		var live: bool = age < 2.0 * FADE_S
		if live and _end[_last].distance_to(end) <= BeamMath.MERGE_END_PX + BeamMath.WOBBLE_PX:
			merge = true
			slot = _last
	if not merge:
		_next = (_next + 1) % MAX_BEAMS
		_merged[slot] = 0
	else:
		_merged[slot] = 1
	_start[slot] = start
	_end[slot] = wobbled
	_born[slot] = now_s
	_width_mul[slot] = jit.x
	_crit[slot] = 1 if crit else (_crit[slot] if merge else 0)
	_last = slot


## Beams alive (any layer visible) at `now_s`; never above MAX_BEAMS.
func live_count(now_s: float) -> int:
	var n: int = 0
	for i: int in MAX_BEAMS:
		if _alpha_of(i, now_s) > 0.0:
			n += 1
	return n


## Linear fade 1 -> 0 over FADE_S; 0 for unborn or expired beams.
static func fade_alpha(age_s: float) -> float:
	return BeamMath.fade_alpha(age_s)


func _alpha_of(i: int, now_s: float) -> float:
	var age: float = now_s - _born[i]
	if _merged[i] != 0:
		return BeamMath.merged_alpha(age)
	return BeamMath.fade_alpha(age)


func _any_active() -> bool:
	for i: int in MAX_BEAMS:
		var age: float = _now_s - _born[i]
		if age >= 0.0 and age < 2.0 * FADE_S:
			return true
	return false


func _load_art() -> void:
	_sheet = ArtSlots.texture("fx_beam_strip")
	_strip = ArtSlots.slot("fx_beam_strip").frame_rect(0)
	# One texel in from the left/right edges so linear sampling never reaches the neighbor cells.
	_strip = Rect2(_strip.position.x + 1.0, _strip.position.y, _strip.size.x - 2.0, _strip.size.y)
	_cap = ArtSlots.slot("fx_beam_cap").frame_rect(0)
	_flare4 = ArtSlots.slot("fx_flare_star_4").frame_rect(0)
	_flare8 = ArtSlots.slot("fx_flare_star_8").frame_rect(0)
	var cone: ArtSlot = ArtSlots.slot("fx_muzzle_cone")
	_cone = cone.frame_rect(0)
	_cone_pivot_x = cone.pivot_frac().x


func _draw() -> void:
	if _sheet == null:
		_load_art()
	var calm: bool = visual != null and visual.reduce_motion
	for i: int in MAX_BEAMS:
		var f: float = _alpha_of(i, _now_s)
		if f > 0.0:
			_draw_beam(i, f)
	for i: int in MAX_BEAMS:
		_draw_muzzle(i, calm)


func _draw_beam(i: int, f: float) -> void:
	var crit: bool = _crit[i] != 0
	var la: Vector2 = BeamMath.length_angle(_start[i], _end[i])
	var w: Vector3 = BeamMath.widths(crit, _width_mul[i])
	var glow: Color = Palette.LASER_GLOW
	glow.a = BeamMath.GLOW_ALPHA * f
	var core: Color = BeamMath.core_color(crit)
	core.a = f
	var hot := Color(1.0, 1.0, 1.0, f)
	# Start end: strip layers run from the emitter; core and hot get a cap behind it, the glow does not.
	draw_set_transform(_start[i], la.y)
	draw_texture_rect_region(_sheet, Rect2(0.0, -w.x * 0.5, la.x, w.x), _strip, glow)
	draw_texture_rect_region(_sheet, Rect2(0.0, -w.y * 0.5, la.x, w.y), _strip, core)
	draw_texture_rect_region(_sheet, Rect2(0.0, -w.z * 0.5, la.x, w.z), _strip, hot)
	draw_set_transform(_start[i], la.y)
	draw_texture_rect_region(_sheet, Rect2(-w.y, -w.y * 0.5, w.y, w.y), _cap, core)
	# Target end: caps in a frame rotated by angle + PI, bright edge on the strip's end.
	draw_set_transform(_end[i], la.y + PI)
	draw_texture_rect_region(_sheet, BeamMath.cap_rect(w.x), _cap, glow)
	draw_texture_rect_region(_sheet, BeamMath.cap_rect(w.y), _cap, core)
	draw_texture_rect_region(_sheet, BeamMath.cap_rect(w.z), _cap, hot)
	if crit:
		var s: float = BeamMath.CRIT_FLARE_PX * lerpf(1.2, 0.8, 1.0 - f)
		draw_set_transform(_end[i], 0.0)
		draw_texture_rect_region(_sheet, Rect2(-s * 0.5, -s * 0.5, s, s), _flare8, Color(1.0, 1.0, 1.0, f))


func _draw_muzzle(i: int, calm: bool) -> void:
	var age: float = _now_s - _born[i]
	var fa: float = BeamMath.flash_alpha(age)
	var ca: float = BeamMath.cone_alpha(age)
	if fa <= 0.0 and ca <= 0.0:
		return
	var angle: float = (_end[i] - _start[i]).angle()
	draw_set_transform(_start[i], angle)
	if ca > 0.0:
		var cone: float = BeamMath.CONE_PX
		var col := Color(1.0, 0.89, 0.64, 0.55 * ca)
		draw_texture_rect_region(_sheet, Rect2(-cone * _cone_pivot_x, -cone * 0.5, cone, cone), _cone, col)
	if fa > 0.0:
		var s: float = BeamMath.FLASH_PX * (1.0 if calm else BeamMath.flash_scale(age))
		draw_texture_rect_region(_sheet, Rect2(-s * 0.5, -s * 0.5, s, s), _flare4, Color(1.0, 0.89, 0.64, fa))


## Beam end in local px: the remapped target position pulled back toward Cinder by
## BEAM_PULLBACK of the sprite's visual radius (the beam stops on the sprite's near edge).
static func beam_end(
	target_m: Vector2, visual_radius_px: float, px_per_m: float, standoff_px: float = ViewMath.STANDOFF_PX
) -> Vector2:
	var p: Vector2 = ViewMath.map_pos(target_m, px_per_m, standoff_px)
	var d: float = p.length()
	if d < 0.001:
		return p
	return p * (maxf(d - BEAM_PULLBACK * visual_radius_px, 0.0) / d)
