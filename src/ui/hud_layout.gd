class_name HudLayout
extends RefCounted
## Applies the portrait or wide layout (V1-28) to the HUD's top bar, upgrade panel and wave banner. Portrait is the
## original V1-24 placement (anchored full width, bottom panel growing upward, offsets = safe margins); wide docks the
## panel to the right edge as a full-height column and confines the top bar and banner to the column left of it.
## `m` = safe margins (left, top, right, bottom) in viewport px. Idempotent: safe to call on every resize.


static func apply(
	mode: LayoutMode.Mode, viewport: Vector2, m: Vector4, top_bar: Control, panel: UpgradePanel, banner: Control
) -> void:
	var wide: bool = mode == LayoutMode.Mode.WIDE
	panel.wide = wide
	if wide:
		var pr: Rect2 = LayoutRects.panel_rect(viewport, m)
		_anchor_panel(panel, 1.0, 0.0)
		panel.offset_left = -m.z - pr.size.x
		panel.offset_right = -m.z
		panel.offset_top = m.y
		panel.offset_bottom = -m.w
		var bar: Rect2 = LayoutRects.hud_bar(viewport, m)
		top_bar.offset_left = bar.position.x
		top_bar.offset_top = m.y
		top_bar.offset_right = bar.end.x - viewport.x
		var col: Rect2 = LayoutRects.hud_column(viewport, m)
		banner.offset_left = col.position.x
		banner.offset_right = col.end.x - viewport.x
	else:
		_anchor_panel(panel, 0.0, 1.0)
		panel.offset_left = m.x
		panel.offset_right = -m.z
		panel.offset_bottom = -m.w
		top_bar.offset_left = m.x
		top_bar.offset_top = m.y
		top_bar.offset_right = -m.z
		banner.offset_left = 0.0
		banner.offset_right = 0.0
	panel.reflow()


## Left anchor 0 (portrait) or 1 (wide: the panel hangs off the right edge); right and bottom stay 1, top is 1
## (portrait, grows upward through `reflow`) or 0 (wide, full height).
static func _anchor_panel(panel: UpgradePanel, left: float, top: float) -> void:
	panel.anchor_left = left
	panel.anchor_right = 1.0
	panel.anchor_top = top
	panel.anchor_bottom = 1.0
