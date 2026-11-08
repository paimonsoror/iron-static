class_name CinderLayout
extends RefCounted
## Pure placement and state-to-cell mapping of the Cinder rig (art bible 4.3 and 4.5, V1-11). No scene access:
## unit-testable headless. Cell rects and pivots come from `ArtSlots`; this file only holds the math the style
## frame (`StyleFrameCinder`) established: body layers at 0.5 px per texel, glow layers (half-size sheet) at 1.0,
## both multiplied by `rig_scale()` so the armor ring outer radius matches the game's Cinder radius.

## Armor ring outer radius in px of the reference art (frame disc r 200 texels at 0.5 px per texel).
const REF_RING_PX: float = 100.0
## The armor ring is this fraction of `CinderView.radius_px` (the emitter ring radius, BattleView).
const ARMOR_FRACTION: float = 0.92
const BODY_PX_PER_TEXEL: float = 0.5
const GLOW_PX_PER_TEXEL: float = 1.0
## Reference-art offsets in px (before `rig_scale`).
const SHADOW_OFFSET := Vector2(8.0, 12.0)
const SHADOW_SCALE: float = 0.575
const SHOULDER_POS := Vector2(-125.0, -22.0)
const SHOULDER_LENS_OFFSET := Vector2(-33.0, -11.0)
const TICKS_POS := Vector2(0.0, 122.0)
const TICKS_SCALE: float = 0.9
## Radius of the three emitter nodes on the ring cell, in texels (lens centers measured on the sheet).
const NODE_RADIUS_TEXELS: float = 204.0
const NODE_COUNT: int = 3
const NODE_STEP: float = TAU / 3.0
## The ring and the visor are authored pointing up: rotation = aim + 90 degrees.
const UP_OFFSET: float = PI * 0.5

const SLOT_SHADOW: String = "cinder_shadow"
const SLOT_FRAME: String = "cinder_frame"
const SLOT_FRAME_HOT: String = "cinder_frame_hot"
const SLOT_RING: String = "cinder_emitter_ring"
const SLOT_RING_GLOW: String = "cinder_emitter_glow"
const SLOT_HOUSING: String = "cinder_core_housing"
const SLOT_CORE: String = "cinder_core"
const SLOT_CORE_HOT: String = "cinder_core_hot"
const SLOT_CRACK: String = "cinder_core_crack"
const SLOT_HALO: String = "cinder_halo_core"
const SLOT_HALO_HOT: String = "cinder_core_hot_halo"
const SLOT_CRACK_GLOW: String = "cinder_core_crack_glow"
const SLOT_VISOR: String = "cinder_visor"
const SLOT_VISOR_GLOW: String = "cinder_visor_glow"
const SLOT_SHOULDER: String = "cinder_shoulder"
const SLOT_SHOULDER_GLOW: String = "cinder_shoulder_glow"
const SLOT_TICKS: String = "cinder_integrity_ticks"
const SLOT_TICKS_GLOW: String = "cinder_integrity_halo"
const SLOT_SEAM_GLOW: String = "cinder_seam_glow"


## Scale of the whole rig relative to the reference art (1.0 = armor ring 100 px).
static func rig_scale(radius_px: float) -> float:
	return radius_px * ARMOR_FRACTION / REF_RING_PX


## Body slot of wedge `k` in `state` (CinderWedges.INTACT/CHARRED; GONE has none, returns ""). Even k uses A, odd B.
static func wedge_slot(k: int, state: int) -> String:
	if state == CinderWedges.GONE:
		return ""
	var even: bool = k % 2 == 0
	if state == CinderWedges.CHARRED:
		return "cinder_wedge_a_charred" if even else "cinder_wedge_b_charred"
	return "cinder_wedge_a_intact" if even else "cinder_wedge_b_intact"


## Glow slot of wedge `k` in `state`: warm seam light on intact plates, the ember rim on charred ones, none when gone.
static func wedge_glow_slot(k: int, state: int) -> String:
	if state == CinderWedges.GONE:
		return ""
	if state == CinderWedges.CHARRED:
		return "cinder_ember_edge_a" if k % 2 == 0 else "cinder_ember_edge_b"
	return SLOT_SEAM_GLOW


## Wedge rotation in radians (the cell holds the sector pointing up).
static func wedge_rotation(k: int) -> float:
	return TAU * float(k) / float(CinderWedges.WEDGE_COUNT)


static func core_slot(band: int) -> String:
	return SLOT_CORE_HOT if band >= 3 else SLOT_CORE


static func core_halo_slot(band: int) -> String:
	return SLOT_HALO_HOT if band >= 3 else SLOT_HALO


static func has_crack(band: int) -> bool:
	return band >= 2


## Frame hot glow (white-hot frame) only in band 3.
static func has_frame_hot(band: int) -> bool:
	return band >= 3


## Glow multiplier by quality tier: 0 when the glow sheets are off (LOW), else 1.
static func glow_factor(glow_sheets: bool) -> float:
	return 1.0 if glow_sheets else 0.0


## Ring rotation in radians that brings emitter node `k` onto `aim` (0 = +x, y down).
static func ring_rotation_for(aim: float, k: int) -> float:
	return aim + UP_OFFSET - NODE_STEP * float(k)


## Ring rotation target for a new aim, picking the node that needs the smallest turn from `current`
## (so a retarget rotates at most 60 degrees; the nearest node becomes the active one).
static func ring_target(current: float, aim: float) -> float:
	var best: float = ring_rotation_for(aim, 0)
	var best_d: float = absf(wrapf(best - current, -PI, PI))
	for k: int in range(1, NODE_COUNT):
		var cand: float = ring_rotation_for(aim, k)
		var d: float = absf(wrapf(cand - current, -PI, PI))
		if d < best_d:
			best_d = d
			best = cand
	return current + wrapf(best - current, -PI, PI)


## Index of the emitter node nearest to `aim` for a ring rotated by `ring_rot`.
static func active_node(ring_rot: float, aim: float) -> int:
	var best: int = 0
	var best_d: float = 1e9
	for k: int in NODE_COUNT:
		var d: float = absf(wrapf(node_angle(ring_rot, k) - aim, -PI, PI))
		if d < best_d:
			best_d = d
			best = k
	return best


## Direction (radians) of node `k` for a ring rotated by `ring_rot` (node 0 points up at rotation 0).
static func node_angle(ring_rot: float, k: int) -> float:
	return ring_rot - UP_OFFSET + NODE_STEP * float(k)


## Node position relative to the Cinder origin, in px, for a rig of `scale_f`.
static func node_position(ring_rot: float, k: int, scale_f: float) -> Vector2:
	return Vector2.from_angle(node_angle(ring_rot, k)) * (NODE_RADIUS_TEXELS * BODY_PX_PER_TEXEL * scale_f)


## Draw rect (position and size in px, relative to the pivot-at-origin transform) of a cell drawn at `px_per_texel`.
static func cell_draw_rect(pivot: Vector2, cell_size: Vector2, px_per_texel: float) -> Rect2:
	return Rect2(-pivot * px_per_texel, cell_size * px_per_texel)
