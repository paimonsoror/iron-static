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
## Art slot id per enemy type (sim row order). The per-type `visual_scale` (walker 0.8, V1 gate) and the
## on-screen hull radius come from `assets/art/slots.csv` through ArtSlots.
const ENEMY_SLOTS: Array[String] = ["skitter", "dart", "walker", "lancer", "boss_hulk"]
## Pixels per meter at 1080 width and the 32 m camera: the reference the slot table sizes are written for.
const REF_PPM: float = 1080.0 / 32.0
## Default extra draw distance for enemies in contact (px), fading out between 2 m and 10 m. Contact enemies
## use `contact_standoff_px` per type instead (their sprite edge rests just outside Cinder's armor ring).
const STANDOFF_PX: float = 72.0
## Gap in px between Cinder's armor ring and the sprite edge of an enemy in contact.
const CONTACT_GAP_PX: float = 4.0
const STANDOFF_NEAR_M: float = 2.0
const STANDOFF_SPAN_M: float = 8.0


## `camera_m` <= 0 uses VIEW_CAMERA_WIDTH_M.
static func px_per_m(viewport_width: float, camera_m: float = 0.0) -> float:
	var cam: float = camera_m if camera_m > 0.0 else VIEW_CAMERA_WIDTH_M
	return viewport_width / cam


## Radial stand-off remap of a distance in meters to a draw distance in px from Cinder.
## Strictly increasing while ppm > standoff_px / STANDOFF_SPAN_M (9 px/m for the default 72 px).
static func map_dist(dist_m: float, ppm: float, standoff_px: float = STANDOFF_PX) -> float:
	var t: float = clampf(1.0 - (dist_m - STANDOFF_NEAR_M) / STANDOFF_SPAN_M, 0.0, 1.0)
	return dist_m * ppm + standoff_px * t


## Sim position (meters, origin Cinder) to draw position (px, origin Cinder). Direction is kept.
## Apply to interpolated positions; never feed the result back into the sim.
static func map_pos(sim_m: Vector2, ppm: float, standoff_px: float = STANDOFF_PX) -> Vector2:
	var d: float = sim_m.length()
	if d < 0.001:
		return Vector2.ZERO
	return sim_m / d * map_dist(d, ppm, standoff_px)


## Multiplier to apply to a sim vector (x, y in meters) to get its draw position (hot loops).
static func map_factor(x_m: float, y_m: float, ppm: float, standoff_px: float = STANDOFF_PX) -> float:
	var d: float = sqrt(x_m * x_m + y_m * y_m)
	if d < 0.001:
		return 0.0
	return map_dist(d, ppm, standoff_px) / d


## Plain length scaling (no stand-off); sprite sizes use visual_radius_px.
static func map_radius(r_m: float, ppm: float) -> float:
	return r_m * ppm


## `visual_scale` column of the enemy type's art slot (1.0 for an unknown index).
static func slot_visual_scale(type_index: int) -> float:
	if type_index < 0 or type_index >= ENEMY_SLOTS.size():
		return 1.0
	return ArtSlots.slot(ENEMY_SLOTS[type_index]).visual_scale


## Scale multiplier of an enemy type (index = sim row), VISUAL_SCALE included.
static func type_scale(type_index: int) -> float:
	return VISUAL_SCALE * slot_visual_scale(type_index)


## On-screen hull radius in px of an enemy type from the slot table (`body_radius_px` x `visual_scale`, scaled
## from the 1080-wide reference); 0 when the slot has none.
static func body_radius_px(type_index: int, ppm: float) -> float:
	if type_index < 0 or type_index >= ENEMY_SLOTS.size():
		return 0.0
	var art: ArtSlot = ArtSlots.slot(ENEMY_SLOTS[type_index])
	return art.body_radius_px * art.visual_scale * ppm / REF_PPM


## Draw radius in px of a sprite: the slot table radius, or `r_m` times the type scale without one.
static func visual_radius_px(r_m: float, type_index: int, ppm: float) -> float:
	var table: float = body_radius_px(type_index, ppm)
	if table > 0.0:
		return table
	return r_m * ppm * type_scale(type_index)


## Stand-off (px, for map_dist) that puts the sprite edge of an enemy standing at `contact_m` just outside
## Cinder's armor ring: center distance = armor radius + sprite radius + CONTACT_GAP_PX.
## Armor ring radius = `cinder_radius_m` x ppm x VISUAL_SCALE (art bible 4.1). Capped below the span that
## would break monotonicity (standoff < SPAN x ppm).
static func contact_standoff_px(
	sprite_radius_px: float, cinder_radius_m: float, ppm: float, contact_m: float = STANDOFF_NEAR_M
) -> float:
	var armor: float = cinder_radius_m * ppm * VISUAL_SCALE
	var t: float = clampf(1.0 - (contact_m - STANDOFF_NEAR_M) / STANDOFF_SPAN_M, 0.0, 1.0)
	var want: float = armor + sprite_radius_px + CONTACT_GAP_PX - contact_m * ppm
	return clampf(want / maxf(t, 0.05), 0.0, STANDOFF_SPAN_M * ppm * 0.95)


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
