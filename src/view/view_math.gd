class_name ViewMath
extends RefCounted
## Pure world-to-screen math for the battle view (GDD 07 section 1, GDD 02 section 2, art bible 4.1).
## The camera shows VIEW_CAMERA_WIDTH_M meters across the viewport width; the battlefield is the
## top BATTLE_FRACTION of the viewport height with Cinder at its center. Sim axes are not
## flipped: +x right, +y down. Sim positions are remapped for drawing only (map_pos).

## Simulation reference camera width (GDD 02 section 2). Documentation only: the V1 view uses
## VIEW_CAMERA_WIDTH_M. 38 m stays selectable (BattleView.camera_width_m) for comparison.
const CAMERA_WIDTH_M: float = 38.0
## V1 view camera width in meters (art bible 4.1, decided at the V1 style-frame gate).
const VIEW_CAMERA_WIDTH_M: float = 32.0
const BATTLE_FRACTION: float = 0.56
## Sprites are drawn at this multiple of the hit radius (art bible 4.1).
const VISUAL_SCALE: float = 1.5
## Per enemy type (sim row order: skitter, dart, walker, lancer, boss_hulk) multiplier on
## VISUAL_SCALE. Walker is about 20% smaller on screen (V1 gate). TODO(V1-02): move to the
## `visual_scale` column of assets/art/slots.csv / ArtSlots when that column exists.
const TYPE_SCALE: Array[float] = [1.0, 1.0, 0.8, 1.0, 1.0]
## Extra draw distance for enemies in contact (px), fading out between 2 m and 10 m.
const STANDOFF_PX: float = 72.0
const STANDOFF_NEAR_M: float = 2.0
const STANDOFF_SPAN_M: float = 8.0


## `camera_m` <= 0 uses VIEW_CAMERA_WIDTH_M.
static func px_per_m(viewport_width: float, camera_m: float = 0.0) -> float:
	var cam: float = camera_m if camera_m > 0.0 else VIEW_CAMERA_WIDTH_M
	return viewport_width / cam


## Radial stand-off remap of a distance in meters to a draw distance in px from Cinder.
## Strictly increasing while ppm > STANDOFF_PX / STANDOFF_SPAN_M (9 px/m).
static func map_dist(dist_m: float, ppm: float) -> float:
	var t: float = clampf(1.0 - (dist_m - STANDOFF_NEAR_M) / STANDOFF_SPAN_M, 0.0, 1.0)
	return dist_m * ppm + STANDOFF_PX * t


## Sim position (meters, origin Cinder) to draw position (px, origin Cinder). Direction is kept.
## Apply to interpolated positions; never feed the result back into the sim.
static func map_pos(sim_m: Vector2, ppm: float) -> Vector2:
	var d: float = sim_m.length()
	if d < 0.001:
		return Vector2.ZERO
	return sim_m / d * map_dist(d, ppm)


## Multiplier to apply to a sim vector (x, y in meters) to get its draw position (hot loops).
static func map_factor(x_m: float, y_m: float, ppm: float) -> float:
	var d: float = sqrt(x_m * x_m + y_m * y_m)
	if d < 0.001:
		return 0.0
	return map_dist(d, ppm) / d


## Plain length scaling (no stand-off); sprite sizes use visual_radius_px.
static func map_radius(r_m: float, ppm: float) -> float:
	return r_m * ppm


## Scale multiplier of an enemy type (index = sim row), VISUAL_SCALE included.
static func type_scale(type_index: int) -> float:
	var k: float = 1.0
	if type_index >= 0 and type_index < TYPE_SCALE.size():
		k = TYPE_SCALE[type_index]
	return VISUAL_SCALE * k


## Draw radius in px of a sprite whose hit radius is `r_m`.
static func visual_radius_px(r_m: float, type_index: int, ppm: float) -> float:
	return r_m * ppm * type_scale(type_index)


static func battle_height(viewport_height: float) -> float:
	return viewport_height * BATTLE_FRACTION


## Screen rectangle of the battlefield (top 56%).
static func battle_rect(viewport_size: Vector2) -> Rect2:
	return Rect2(0.0, 0.0, viewport_size.x, battle_height(viewport_size.y))


## Cinder's screen position: center of the battle area.
static func cinder_center(viewport_size: Vector2) -> Vector2:
	return Vector2(viewport_size.x * 0.5, battle_height(viewport_size.y) * 0.5)


## Linear (no stand-off) screen position; use map_pos + cinder_center for drawn things.
static func world_to_screen(world_m: Vector2, viewport_size: Vector2, camera_m: float = 0.0) -> Vector2:
	return cinder_center(viewport_size) + world_m * px_per_m(viewport_size.x, camera_m)
