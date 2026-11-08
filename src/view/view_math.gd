class_name ViewMath
extends RefCounted
## Pure world-to-screen math for the battle view (GDD 07 section 1, GDD 02 section 2).
## The camera shows CAMERA_WIDTH_M meters across the viewport width; the battlefield is the
## top BATTLE_FRACTION of the viewport height with Cinder at its center. Sim axes are not
## flipped: +x right, +y down.

const CAMERA_WIDTH_M: float = 38.0
const BATTLE_FRACTION: float = 0.56


static func px_per_m(viewport_width: float) -> float:
	return viewport_width / CAMERA_WIDTH_M


static func battle_height(viewport_height: float) -> float:
	return viewport_height * BATTLE_FRACTION


## Screen rectangle of the battlefield (top 56%).
static func battle_rect(viewport_size: Vector2) -> Rect2:
	return Rect2(0.0, 0.0, viewport_size.x, battle_height(viewport_size.y))


## Cinder's screen position: center of the battle area.
static func cinder_center(viewport_size: Vector2) -> Vector2:
	return Vector2(viewport_size.x * 0.5, battle_height(viewport_size.y) * 0.5)


static func world_to_screen(world_m: Vector2, viewport_size: Vector2) -> Vector2:
	return cinder_center(viewport_size) + world_m * px_per_m(viewport_size.x)
