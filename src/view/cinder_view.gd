class_name CinderView
extends Node2D
## Cinder as a layered, animated sprite rig (V1-11, art bible 4.2 and 4.5). Pure observer: the battle view feeds it
## band/hp/aim from the sim each frame via set_state(). Origin = center. The metallic art comes from the `cinder`
## and `cinder_glow` sheets through `ArtSlots`; `CinderRig` holds state and paints, this node owns the two canvas
## layers (body = normal blend, glow = additive) and the procedural integrity ring. Draw calls: integrity arcs,
## body batch, glow batch. Range rings belong to the battle view.

const INTEGRITY_POINTS: int = 96
const INTEGRITY_RING: float = 1.32

## Outer radius of the emitter ring in pixels (battle view sets it from the visual scale); the armor ring is 0.92 of it.
var radius_px: float = 110.0:
	set(value):
		radius_px = maxf(value, 8.0)
		_rig.scale_f = CinderLayout.rig_scale(radius_px)
		queue_redraw()
## Visual options (quality tier, reduce motion); null = HIGH defaults. Set by BattleView.
var visual: VisualSettings = null
## Heartbeat clock shared with the arena overlay (sim time); < 0 = use the view clock. Set by BattleView.
var heart_clock_s: float = -1.0

var _hp_frac: float = 1.0
var _ring_pts := PackedVector2Array()
var _ring_cols := PackedColorArray()
var _rig := CinderRig.new()
var _body := CinderLayer.new()
var _glow := CinderLayer.new()


func _init() -> void:
	_ring_pts.resize(INTEGRITY_POINTS + 1)
	_ring_cols.resize(INTEGRITY_POINTS + 1)
	_rig.scale_f = CinderLayout.rig_scale(radius_px)
	_body.painter = _rig.paint_body
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_glow.painter = _rig.paint_glow
	_glow.make_additive()
	add_child(_body)
	add_child(_glow)


## Feed the latest sim values. `aim_angle` radians (0 = +x, y down), `time_s` view clock.
func set_state(hp_frac: float, band: int, aim_angle: float, time_s: float) -> void:
	_hp_frac = clampf(hp_frac, 0.0, 1.0)
	var glow_on: bool = true
	if visual != null:
		glow_on = visual.quality.glow_sheets
		_rig.reduce_motion = visual.reduce_motion
		_rig.animate = visual.quality.wedge_anim
	_rig.glow_mul = CinderLayout.glow_factor(glow_on)
	_rig.update(clampi(band, 0, 3), aim_angle, time_s, heart_clock_s)
	_glow.visible = glow_on
	var shiver: Vector2 = _rig.shiver()
	_body.position = shiver
	_glow.position = shiver
	queue_redraw()
	_body.queue_redraw()
	_glow.queue_redraw()


## Selects the frame variant of the rig (`vanguard`, `bulwark`, `striker`; M3-27). Called by `BattleView.bind` from
## `world.config.frame_id`; unknown ids draw VANGUARD.
func set_frame(id: String) -> void:
	_rig.set_frame(id)
	queue_redraw()
	_body.queue_redraw()
	_glow.queue_redraw()


func frame_id() -> String:
	return _rig.spec.frame_id


## A hit on Cinder (`CINDER_HIT`): core flash and frame shiver (off under reduce motion).
func notify_hit() -> void:
	_rig.notify_hit()


## A shot left emitter node `emitter_index` (-1 = the active one): muzzle and lens brightness (V1-12 hook).
func notify_shot(_emitter_index: int = -1) -> void:
	_rig.notify_shot()


## Index 0..2 of the emitter node nearest to the aim.
func active_emitter() -> int:
	return _rig.active_node()


## Beam origin: position of the active emitter node relative to Cinder's origin (px). Add `global_position`
## for screen space.
func emitter_position() -> Vector2:
	return _rig.emitter_position()


## Position of emitter node `k` relative to Cinder's origin (px).
func emitter_node_position(k: int) -> Vector2:
	return CinderLayout.node_position(_rig.ring_rot, k, _rig.scale_f, _rig.spec.node_radius_texels)


func rig() -> CinderRig:
	return _rig


func _draw() -> void:
	# One polyline call: segments up to the hp fraction in the integrity color, the rest in the track color.
	var ring_r: float = radius_px * INTEGRITY_RING
	var n: int = INTEGRITY_POINTS
	var filled: int = ceili(_hp_frac * float(n))
	var col: Color = _integrity_color(_hp_frac)
	for i: int in n:
		var ang: float = -PI * 0.5 + TAU * float(i) / float(n)
		_ring_pts[i] = Vector2.from_angle(ang) * ring_r
		_ring_cols[i] = col if i < filled else Palette.GRID
	_ring_pts[n] = _ring_pts[0]
	_ring_cols[n] = _ring_cols[n - 1]
	draw_polyline_colors(_ring_pts, _ring_cols, 3.0, false)


## Teal (full) to amber (half) to red (quarter and below).
static func _integrity_color(hp_frac: float) -> Color:
	var pal: PaletteSet = Palette.current()
	if hp_frac >= 0.5:
		return pal.amber.lerp(pal.teal, (hp_frac - 0.5) / 0.5)
	return pal.critical.lerp(pal.amber, clampf((hp_frac - 0.25) / 0.25, 0.0, 1.0))
