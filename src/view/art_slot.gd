class_name ArtSlot
extends RefCounted
## One row of `assets/art/slots.csv`: where a sprite lives on its sheet and how to place it (view data, no sim access).
## Rectangles are in texels of the slot's own sheet file; glow slots are separate rows (own file, half size).

var id: String = ""
## Sheet path relative to `res://assets/art/src/` (empty = reserved).
var file: String = ""
var glow_file: String = ""
## Slot id of the paired additive glow cell(s), or "".
var glow_slot: String = ""
var sheet_size: Vector2i = Vector2i.ZERO
## Origin and size of frame 0; further frames follow to the right in steps of `cell_size.x`.
var cell_pos: Vector2i = Vector2i.ZERO
var cell_size: Vector2i = Vector2i.ZERO
var frames: int = 1
## Pivot in texels inside the cell (ui rows: 9-slice margins left/right and top/bottom).
var pivot: Vector2 = Vector2.ZERO
## Flipbook rate; 0 = picked by the view (events).
var fps: float = 0.0
## On-screen hull radius at 1080 width before `visual_scale`; 0 = n/a.
var body_radius_px: float = 0.0
## Texels per on-screen px; 0 = DPI independent (icons).
var texel_per_px: float = 0.0
## Per-slot multiplier on the global visual scale (walker 0.8, V1-GATE).
var visual_scale: float = 1.0
## Expected width/height of the solid silhouette; 0 = none.
var aspect: float = 0.0
## Texels that must stay transparent inside the cell border (pixel check).
var margin: int = 0
## Minimum percent of cell pixels that must be visible (pixel check); 3 unless the row says otherwise.
var min_coverage: float = 3.0
var additive: bool = false
var family: String = ""
## ready | todo | reserved
var status: String = ""
var notes: String = ""
## False for the stand-in returned for an unknown id.
var valid: bool = false


func is_reserved() -> bool:
	return file.is_empty() or status == "reserved"


## Rect of `frame` in texels (frame is clamped into 0..frames-1).
func frame_rect(frame: int) -> Rect2:
	var f: int = clampi(frame, 0, maxi(frames - 1, 0))
	return Rect2(Vector2(cell_pos.x + f * cell_size.x, cell_pos.y), Vector2(cell_size))


## Rect of `frame` in 0..1 UV space of the whole sheet.
func frames_uv(frame: int) -> Rect2:
	if sheet_size.x <= 0 or sheet_size.y <= 0:
		return Rect2(0.0, 0.0, 1.0, 1.0)
	var r: Rect2 = frame_rect(frame)
	var sheet: Vector2 = Vector2(sheet_size)
	return Rect2(r.position / sheet, r.size / sheet)


## Pivot as a 0..1 fraction of the cell.
func pivot_frac() -> Vector2:
	if cell_size.x <= 0 or cell_size.y <= 0:
		return Vector2(0.5, 0.5)
	return pivot / Vector2(cell_size)


## On-screen pixels per texel at 1080 width including `visual_scale` (1 for DPI independent slots).
func sprite_scale() -> float:
	if texel_per_px <= 0.0:
		return visual_scale
	return visual_scale / texel_per_px
