class_name LayoutRects
extends RefCounted
## Rect math of the wide layout (V1-28), all in viewport px, `m` = safe margins (left, top, right, bottom).
## The upgrade panel is a full-height column on the right; the HUD and the field live left of it.

## Panel width as a share of the viewport width, clamped: four tabs need about 185 px each at body size (7 letters), so
## 40 percent, not less; the field keeps the rest.
const PANEL_SHARE: float = 0.40
const PANEL_MIN_PX: float = 700.0
const PANEL_MAX_PX: float = 840.0
## The top bar never gets wider than its portrait design width (long empty bars look broken).
const HUD_MAX_PX: float = 1080.0


static func panel_width(viewport_w: float) -> float:
	return minf(clampf(viewport_w * PANEL_SHARE, PANEL_MIN_PX, PANEL_MAX_PX), viewport_w * 0.5)


## Side panel: right edge inset by the safe margin, full height between the top and bottom margins.
static func panel_rect(viewport: Vector2, m: Vector4) -> Rect2:
	var w: float = panel_width(viewport.x)
	return Rect2(viewport.x - m.z - w, m.y, w, maxf(viewport.y - m.y - m.w, 0.0))


## Column left of the panel that holds the HUD (x from the left safe margin).
static func hud_column(viewport: Vector2, m: Vector4) -> Rect2:
	var right: float = panel_rect(viewport, m).position.x
	return Rect2(m.x, m.y, maxf(right - m.x, 0.0), maxf(viewport.y - m.y, 0.0))


## Top bar: the column's width capped at HUD_MAX_PX and centered in it.
static func hud_bar(viewport: Vector2, m: Vector4) -> Rect2:
	var col: Rect2 = hud_column(viewport, m)
	var w: float = minf(col.size.x, HUD_MAX_PX)
	return Rect2(col.position.x + (col.size.x - w) * 0.5, col.position.y, w, col.size.y)


## Field the battle view centers in: from the screen's left edge to the panel, `top_px` (HUD bottom) down to the
## bottom safe margin.
static func field(viewport: Vector2, m: Vector4, top_px: float) -> Rect2:
	var right: float = panel_rect(viewport, m).position.x
	var top: float = clampf(top_px, 0.0, viewport.y)
	return Rect2(0.0, top, right, maxf(viewport.y - m.w - top, 1.0))
