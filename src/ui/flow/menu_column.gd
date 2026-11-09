class_name MenuColumn
extends RefCounted
## Menu content column (M3-14): the rect a menu screen lays its content in. PORTRAIT: the whole view inside the
## safe margins. WIDE (near-square foldable, `LayoutMode`): capped at `MAX_WIDTH` base px and centered in the safe
## area. Pure; `m` = safe margins (left, top, right, bottom) in viewport px.

const MAX_WIDTH: float = 1080.0


static func rect(viewport: Vector2, m: Vector4, mode: LayoutMode.Mode) -> Rect2:
	var avail := Rect2(m.x, m.y, maxf(viewport.x - m.x - m.z, 0.0), maxf(viewport.y - m.y - m.w, 0.0))
	if mode != LayoutMode.Mode.WIDE or avail.size.x <= MAX_WIDTH:
		return avail
	return Rect2(avail.position.x + (avail.size.x - MAX_WIDTH) * 0.5, avail.position.y, MAX_WIDTH, avail.size.y)
