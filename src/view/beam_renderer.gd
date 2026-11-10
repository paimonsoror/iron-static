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
const LASER_ROW_ID: String = "laser_output"
## Impact flares at or above this size use the 8-point star (MK III, IV); smaller ones the 4-point star.
const STAR8_MIN_PX: float = 90.0
## Ripple bands travel emitter to target this many times a second; band half-length and fade-in distance in px.
const RIPPLE_HZ: float = 3.0
const RIPPLE_FADE_PX: float = 40.0

## Width/size multiplier of every beam layer, flare and cone (V1-23: the sprite factor, 1.0 = pre-V1-23 pixels).
var px_scale: float = 1.0
## Optional: reduce motion switches off jitter, wobble and the flare scale animation.
var visual: VisualSettings
## Optional floor scorch lines (R1-06), fed on every plain shot; set by the battle view.
var scorch: BeamScorch

## Current tier look (VT-2). Replaced only when the laser_output run level crosses a tier; MK I = today's constants.
var look: BeamLook = BeamLook.new()

var _laser_row: int = -1
var _level: int = 0
var _start := PackedVector2Array()
var _end := PackedVector2Array()
var _born := PackedFloat32Array()
var _width_mul := PackedFloat32Array()
var _crit := PackedByteArray()
var _merged := PackedByteArray()
var _fade := PackedFloat32Array()
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
var _ring: Rect2
var _calm: bool = false
var _tier: int = 0
var _do_flare: bool = false
var _do_ring: bool = false
var _do_rim: bool = false
var _do_ripple: bool = false


func _init() -> void:
	var ok: bool = _start.resize(MAX_BEAMS) == OK
	ok = ok and _end.resize(MAX_BEAMS) == OK
	ok = ok and _born.resize(MAX_BEAMS) == OK
	ok = ok and _width_mul.resize(MAX_BEAMS) == OK
	ok = ok and _crit.resize(MAX_BEAMS) == OK
	ok = ok and _merged.resize(MAX_BEAMS) == OK
	ok = ok and _fade.resize(MAX_BEAMS) == OK
	ok = ok and _times.resize(RATE_RING) == OK
	if not ok:
		push_error("BeamRenderer: resize failed")
	for i: int in MAX_BEAMS:
		_born[i] = -1000.0
		_width_mul[i] = 1.0
		_fade[i] = FADE_S
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
	_laser_row = -1
	for i: int in world.config.upgrades.size():
		if world.config.upgrades[i].id == LASER_ROW_ID:
			_laser_row = i
			break
	_level = 0
	look = BeamLook.for_level(0)
	_track_level(world)


## Switches `look` when the laser_output run level has crossed a tier. An int compare per frame; the model is
## consulted only when the level itself changed (a purchase).
func _track_level(world: SimWorld) -> void:
	if _laser_row < 0 or _laser_row >= world.run_levels.size():
		return
	var level: int = world.run_levels[_laser_row]
	if level == _level:
		return
	_level = level
	var tier: int = VisualTierModel.shared().tier_for(LASER_ROW_ID, level)
	if tier != look.tier:
		look = BeamLook.for_level(level)


## Consumes new SHOT_FIRED events and redraws. `now_s` is monotonic wall time (seconds),
## `emitter_px` the beam start in local pixels, `enemies` supplies the per-type stand-off (null = default).
func update(world: SimWorld, now_s: float, px_per_m: float, emitter_px: Vector2, enemies: EnemyRenderer = null) -> void:
	_now_s = now_s
	_track_level(world)
	var store: EnemyStore = world.enemies
	if scorch != null:
		scorch.update(now_s)
	while _events.poll(world.events) > 0:
		for i: int in _events.count:
			if _events.kind_at(i) != SimEventKind.SHOT_FIRED:
				continue
			var idx: int = _events.a_at(i)
			if idx < 0 or idx >= store.high_water:
				continue
			var type: int = store.type_id[idx]
			var vis_r: float = ViewMath.visual_radius_px(store.radius[idx], type, px_per_m)
			if enemies != null:
				vis_r = enemies.sprite_radius_px(type)
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
	var rate: int = BeamMath.shots_in_window(_times, now_s)
	if _last >= 0 and BeamMath.should_merge(rate):
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
	_fade[slot] = BeamAfterglow.core_fade_s(rate)
	if scorch != null and not merge:
		scorch.add(start, wobbled, now_s)
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
	return BeamMath.fade_alpha(age, _fade[i])


func _any_active() -> bool:
	for i: int in MAX_BEAMS:
		var age: float = _now_s - _born[i]
		if age >= 0.0 and age < BeamAfterglow.GLOW_S:  # the longest beam-layer life (afterglow 0.3 s, merged 0.16 s)
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
	_ring = ArtSlots.slot("fx_ring_thin").frame_rect(0)


func _draw() -> void:
	if _sheet == null:
		_load_art()
	_resolve_quality()
	@warning_ignore("return_value_discarded")
	_afterglow_pass(true)
	for i: int in MAX_BEAMS:
		var f: float = _alpha_of(i, _now_s)
		if f > 0.0:
			_draw_beam(i, f)
	for i: int in MAX_BEAMS:
		_draw_muzzle(i, _calm)


## Names of the optional tier parts drawn now (flare, ring, rim, ripple), for tests and the debug harness.
func active_parts() -> PackedStringArray:
	_resolve_quality()
	var out := PackedStringArray()
	if _do_flare:
		out.append("flare")
	if _do_ring:
		out.append("ring")
	if _do_rim:
		out.append("rim")
	if _do_ripple:
		out.append("ripple")
	return out


## Which parts of the tier look are drawn (spec 12 section 8): LOW keeps thickness and color only; MID drops the
## ripple and the impact ring; reduce motion drops the ripple and keeps the ring without its scale animation.
func _resolve_quality() -> void:
	_calm = visual != null and visual.reduce_motion
	var q: VisualQuality = null if visual == null else visual.quality
	_tier = VisualQuality.Tier.HIGH if q == null else q.tier
	var low: bool = q != null and q.tier == VisualQuality.Tier.LOW
	var rings_ok: bool = q == null or q.impact_rings
	var mid_up: bool = q == null or q.tier == VisualQuality.Tier.HIGH
	_do_flare = not low and look.flare_px > 0.0
	_do_ring = not low and rings_ok and look.ring_px > 0.0
	_do_rim = not low and look.rim > 0.0
	_do_ripple = not low and mid_up and not _calm and look.ripple > 0


func _draw_beam(i: int, f: float) -> void:
	var crit: bool = _crit[i] != 0
	var la: Vector2 = BeamMath.length_angle(_start[i], _end[i])
	var w: Vector3 = BeamMath.widths_for(look, crit, _width_mul[i] * px_scale)
	var glow: Color = BeamMath.glow_color(look.whiten)
	glow.a = BeamMath.GLOW_ALPHA * f
	var core: Color = BeamMath.core_color_for(crit, look.whiten)
	core.a = f
	var hot := Color(1.0, 1.0, 1.0, f)
	# Start end: strip layers run from the emitter; core and hot get a cap behind it, the glow does not.
	draw_set_transform(_start[i], la.y)
	draw_texture_rect_region(_sheet, Rect2(0.0, -w.x * 0.5, la.x, w.x), _strip, glow)
	if _do_rim:
		var teal: Color = Palette.current().teal
		teal.a = look.rim * f
		draw_texture_rect_region(_sheet, Rect2(0.0, -w.x * 0.36, la.x, w.x * 0.72), _strip, teal)
	draw_texture_rect_region(_sheet, Rect2(0.0, -w.y * 0.5, la.x, w.y), _strip, core)
	draw_texture_rect_region(_sheet, Rect2(0.0, -w.z * 0.5, la.x, w.z), _strip, hot)
	if _do_ripple:
		_draw_ripples(la.x, w, f)
		draw_set_transform(_start[i], la.y)
	draw_texture_rect_region(_sheet, Rect2(-w.y, -w.y * 0.5, w.y, w.y), _cap, core)
	# Target end: caps in a frame rotated by angle + PI, bright edge on the strip's end.
	draw_set_transform(_end[i], la.y + PI)
	draw_texture_rect_region(_sheet, BeamMath.cap_rect(w.x), _cap, glow)
	draw_texture_rect_region(_sheet, BeamMath.cap_rect(w.y), _cap, core)
	draw_texture_rect_region(_sheet, BeamMath.cap_rect(w.z), _cap, hot)
	_draw_impact(_end[i], f, crit)


## Charge ripple (MK IV): bright teal-white bands that travel from the emitter to the target, in the beam's frame.
func _draw_ripples(length: float, w: Vector3, f: float) -> void:
	var gap: float = length / float(look.ripple)
	var phase: float = fposmod(_now_s * RIPPLE_HZ, 1.0)
	var band: Color = Palette.current().teal.lerp(Color.WHITE, 0.7)
	for k: int in look.ripple:
		var x: float = fposmod((float(k) + phase) * gap, length)
		var a: float = clampf(minf(x, length - x) / RIPPLE_FADE_PX, 0.0, 1.0) * f
		band.a = 0.9 * a
		draw_texture_rect_region(
			_sheet, Rect2(x - 7.0 * px_scale, -w.y * 1.05, 14.0 * px_scale, w.y * 2.1), _strip, band
		)
		var cw := Color(1.0, 1.0, 1.0, 0.8 * a)
		draw_texture_rect_region(_sheet, Rect2(x - 3.0 * px_scale, -w.z * 0.9, 6.0 * px_scale, w.z * 1.8), _strip, cw)


## Impact at the target: the tier flare (a crit uses at least the crit flare size) and the thin ring.
func _draw_impact(at: Vector2, f: float, crit: bool) -> void:
	var flare: float = look.flare_px if _do_flare else 0.0
	if crit:
		flare = maxf(flare, BeamMath.CRIT_FLARE_PX)
	if flare <= 0.0 and not _do_ring:
		return
	draw_set_transform(at, 0.0)
	if flare > 0.0:
		var s: float = flare * px_scale
		if crit or not _calm:
			s *= lerpf(1.2, 0.8, 1.0 - f)
		var slot: Rect2 = _flare8 if (crit or flare >= STAR8_MIN_PX) else _flare4
		var c: Color = Color(1.0, 1.0, 1.0, f)
		if not crit:
			c = Color(1.0, 0.89, 0.64, f).lerp(c, look.whiten)
		draw_texture_rect_region(_sheet, Rect2(-s * 0.5, -s * 0.5, s, s), slot, c)
	if _do_ring:
		var r: float = look.ring_px * px_scale
		if not _calm:
			r *= lerpf(0.7, 1.0, 1.0 - f)
		var rc: Color = Palette.AMBER_GLOW
		rc.a = 0.75 * f
		draw_texture_rect_region(_sheet, Rect2(-r * 0.5, -r * 0.5, r, r), _ring, rc)


func _draw_muzzle(i: int, calm: bool) -> void:
	var age: float = _now_s - _born[i]
	var fa: float = BeamMath.flash_alpha(age)
	var ca: float = BeamMath.cone_alpha(age)
	if fa <= 0.0 and ca <= 0.0:
		return
	var mul: float = px_scale
	if _do_flare:
		mul *= look.muzzle
	var angle: float = (_end[i] - _start[i]).angle()
	draw_set_transform(_start[i], angle)
	if ca > 0.0:
		var cone: float = BeamMath.CONE_PX * mul
		var col := Color(1.0, 0.89, 0.64, 0.55 * ca)
		draw_texture_rect_region(_sheet, Rect2(-cone * _cone_pivot_x, -cone * 0.5, cone, cone), _cone, col)
	if fa > 0.0:
		var s: float = BeamMath.FLASH_PX * mul * (1.0 if calm else BeamMath.flash_scale(age))
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


## Afterglows drawn now (R1-06): plain beams younger than `BeamAfterglow.GLOW_S`, newest first, at most the tier cap.
func afterglow_count(now_s: float) -> int:
	_now_s = now_s
	_resolve_quality()
	return _afterglow_pass(false)


## Draws (or only counts) the afterglows: a widened, fading copy of the tier's glow layer under the live beam.
func _afterglow_pass(draw: bool) -> int:
	var cap: int = BeamAfterglow.glow_cap(_tier)
	var n: int = 0
	for k: int in MAX_BEAMS:
		if n >= cap:
			break
		var i: int = posmod(_next - 1 - k, MAX_BEAMS)
		if _merged[i] != 0:
			continue
		var a: float = BeamAfterglow.glow_alpha(_now_s - _born[i], _calm)
		if a <= 0.0:
			continue
		n += 1
		if draw:
			var la: Vector2 = BeamMath.length_angle(_start[i], _end[i])
			var widths: Vector3 = BeamMath.widths_for(look, _crit[i] != 0, _width_mul[i] * px_scale)
			var w: float = widths.x * BeamAfterglow.GLOW_WIDTH_MUL
			var col: Color = BeamMath.glow_color(look.whiten)
			col.a = a
			draw_set_transform(_start[i], la.y)
			draw_texture_rect_region(_sheet, Rect2(0.0, -w * 0.5, la.x, w), _strip, col)
	return n
