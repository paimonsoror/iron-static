class_name UtFlash
extends Node2D
## Style-frame tier-up flash on Cinder: a soft halo, an expanding ring and a flare, all from the `fx_sheet` cells,
## additive. Debug only. `t` is seconds since the tier-up; the production version runs the same three quads from the
## view clock for 0.45 s (spec 12 s5).

const DURATION_S: float = 0.45

var t: float = 0.0
var radius_px: float = 70.0
var tint: Color = Palette.AMBER_GLOW


func _draw() -> void:
	if t < 0.0 or t > DURATION_S:
		return
	var sheet: Texture2D = ArtSlots.texture("fx_halo_soft")
	var u: float = t / DURATION_S
	var fade: float = 1.0 - u
	var halo: Rect2 = ArtSlots.slot("fx_halo_soft").frame_rect(0)
	var hs: float = radius_px * lerpf(3.4, 5.2, u)
	var hc: Color = tint
	hc.a = 0.5 * fade
	draw_texture_rect_region(sheet, Rect2(-hs * 0.5, -hs * 0.5, hs, hs), halo, hc)
	var ring: Rect2 = ArtSlots.slot("fx_ring_thick").frame_rect(0)
	var rs: float = radius_px * lerpf(2.4, 6.0, 1.0 - pow(1.0 - u, 2.0))
	var rc: Color = Palette.TEAL.lerp(Color.WHITE, 0.45)
	rc.a = 0.9 * fade
	draw_texture_rect_region(sheet, Rect2(-rs * 0.5, -rs * 0.5, rs, rs), ring, rc)
	var ring2: Rect2 = ArtSlots.slot("fx_ring_thin").frame_rect(0)
	var r2: float = radius_px * lerpf(2.0, 4.2, 1.0 - pow(1.0 - u, 3.0))
	var r2c: Color = Palette.AMBER_GLOW
	r2c.a = 0.8 * fade
	draw_texture_rect_region(sheet, Rect2(-r2 * 0.5, -r2 * 0.5, r2, r2), ring2, r2c)
	var star: Rect2 = ArtSlots.slot("fx_flare_star_8").frame_rect(0)
	var ss: float = radius_px * lerpf(2.2, 3.6, u)
	var sc := Color(1.0, 0.96, 0.85, 0.75 * fade)
	draw_texture_rect_region(sheet, Rect2(-ss * 0.5, -ss * 0.5, ss, ss), star, sc)
