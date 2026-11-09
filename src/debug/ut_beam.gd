class_name UtBeam
extends BeamRenderer
## Style-frame beam: the production BeamRenderer (pool, merge, jitter, fade, art loading) with a tiered `_draw`.
## Look params come from visual_tiers.proposed.csv (`glow core hot flare ring whiten rim ripple muzzle`).
## Same three strip quads and caps on the same sheet and material, so the draw-call count stays at the production 1-2.
## Debug only: the production change would be a `BeamLook` struct passed to `_draw_beam` (spec 12 s7).

var look: Dictionary = {}
## Phase of the charge ripple in bands (static frames pick one).
var ripple_phase: float = 0.0


func _px(key: String, fallback: float) -> float:
	var v: float = look.get(key, fallback)
	return v


func _draw() -> void:
	if _sheet == null:
		_load_art()
	for i: int in MAX_BEAMS:
		var f: float = _alpha_of(i, _now_s)
		if f > 0.0:
			_tier_beam(i, f)
	for i: int in MAX_BEAMS:
		_tier_muzzle(i)


func _tier_beam(i: int, f: float) -> void:
	var crit: bool = _crit[i] != 0
	var la: Vector2 = BeamMath.length_angle(_start[i], _end[i])
	var m: float = _width_mul[i] * px_scale * (BeamMath.CRIT_WIDTH_MUL if crit else 1.0)
	var w := Vector3(_px("glow", 36.0) * m, _px("core", 8.0) * m, _px("hot", 3.0) * m)
	var whiten: float = _px("whiten", 0.0)
	var glow: Color = Palette.LASER_GLOW.lerp(Palette.AMBER_GLOW, whiten * 0.5)
	glow.a = BeamMath.GLOW_ALPHA * f
	var core: Color = Palette.LASER_CORE.lerp(Color.WHITE, whiten)
	core.a = f
	var hot := Color(1.0, 1.0, 1.0, f)
	draw_set_transform(_start[i], la.y)
	draw_texture_rect_region(_sheet, Rect2(0.0, -w.x * 0.5, la.x, w.x), _strip, glow)
	var rim: float = _px("rim", 0.0)
	if rim > 0.0:
		var teal: Color = Palette.TEAL
		teal.a = rim * f
		draw_texture_rect_region(_sheet, Rect2(0.0, -w.x * 0.36, la.x, w.x * 0.72), _strip, teal)
	draw_texture_rect_region(_sheet, Rect2(0.0, -w.y * 0.5, la.x, w.y), _strip, core)
	draw_texture_rect_region(_sheet, Rect2(0.0, -w.z * 0.5, la.x, w.z), _strip, hot)
	var ripples: int = int(_px("ripple", 0.0))
	if ripples > 0:
		_ripples(la.x, w, f, ripples)
	draw_set_transform(_start[i], la.y)
	draw_texture_rect_region(_sheet, Rect2(-w.y, -w.y * 0.5, w.y, w.y), _cap, core)
	draw_set_transform(_end[i], la.y + PI)
	draw_texture_rect_region(_sheet, BeamMath.cap_rect(w.x), _cap, glow)
	draw_texture_rect_region(_sheet, BeamMath.cap_rect(w.y), _cap, core)
	draw_texture_rect_region(_sheet, BeamMath.cap_rect(w.z), _cap, hot)
	_impact(_end[i], f, crit)


## Charge ripple: bright bands that travel from the emitter to the target.
func _ripples(length: float, w: Vector3, f: float, count: int) -> void:
	var gap: float = length / float(count)
	for k: int in count:
		var x: float = fposmod((float(k) + ripple_phase) * gap, length)
		var edge: float = minf(x, length - x) / 40.0
		var a: float = clampf(edge, 0.0, 1.0) * f
		var c: Color = Palette.TEAL.lerp(Color.WHITE, 0.7)
		c.a = 0.9 * a
		draw_texture_rect_region(_sheet, Rect2(x - 7.0 * px_scale, -w.y * 1.05, 14.0 * px_scale, w.y * 2.1), _strip, c)
		var cw: Color = Color(1.0, 1.0, 1.0, 0.8 * a)
		draw_texture_rect_region(_sheet, Rect2(x - 3.0 * px_scale, -w.z * 0.9, 6.0 * px_scale, w.z * 1.8), _strip, cw)


func _impact(at: Vector2, f: float, crit: bool) -> void:
	var flare: float = _px("flare", 0.0) * px_scale
	var ring: float = _px("ring", 0.0) * px_scale
	if flare <= 0.0 and not crit:
		return
	draw_set_transform(at, 0.0)
	if flare > 0.0:
		var slot: Rect2 = _flare8 if flare > 70.0 * px_scale else _flare4
		var c: Color = Color(1.0, 0.89, 0.64, f).lerp(Color(1.0, 1.0, 1.0, f), _px("whiten", 0.0))
		draw_texture_rect_region(_sheet, Rect2(-flare * 0.5, -flare * 0.5, flare, flare), slot, c)
	if ring > 0.0:
		var rg: Rect2 = ArtSlots.slot("fx_ring_thin").frame_rect(0)
		var rc: Color = Palette.AMBER_GLOW
		rc.a = 0.75 * f
		draw_texture_rect_region(_sheet, Rect2(-ring * 0.5, -ring * 0.5, ring, ring), rg, rc)


func _tier_muzzle(i: int) -> void:
	var age: float = _now_s - _born[i]
	var fa: float = BeamMath.flash_alpha(age)
	var ca: float = BeamMath.cone_alpha(age)
	if fa <= 0.0 and ca <= 0.0:
		return
	var mul: float = _px("muzzle", 1.0) * px_scale
	var angle: float = (_end[i] - _start[i]).angle()
	draw_set_transform(_start[i], angle)
	if ca > 0.0:
		var cone: float = BeamMath.CONE_PX * mul
		var cc := Color(1.0, 0.89, 0.64, 0.55 * ca)
		draw_texture_rect_region(_sheet, Rect2(-cone * _cone_pivot_x, -cone * 0.5, cone, cone), _cone, cc)
	if fa > 0.0:
		var s: float = BeamMath.FLASH_PX * mul * BeamMath.flash_scale(age)
		draw_texture_rect_region(_sheet, Rect2(-s * 0.5, -s * 0.5, s, s), _flare4, Color(1.0, 0.89, 0.64, fa))
