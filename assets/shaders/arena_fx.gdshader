shader_type canvas_item;
// IRON STATIC arena floor + animated light, ONE opaque full-rect pass (art bible 6.7, V1-08).
// Samples the static arena_floor art and adds, analytically: polar grid (spokes every 30 deg, rings every
// 10 m), radar sweep, range-ring pulse and the optic range ring. Scanlines, vignette and the low-HP haze live in
// arena_overlay.gdshader, which draws above the sprites. No TIME: the view clock arrives as sweep_phase and
// pulse_phase (0..1), so pausing the sim freezes the animation.
//
// Local space: origin = Cinder, y down. rect_origin_px = top-left of the rect in that space, rect_px = its size.
// Art is authored at 1080 x 1344 with Cinder's pad at (540, 672); art_scale = px_per_m / 33.75.
render_mode unshaded;

uniform sampler2D floor_tex : source_color, filter_linear, repeat_disable;
uniform vec2 art_size = vec2(1080.0, 1344.0);
uniform vec2 art_center = vec2(540.0, 672.0);
uniform float art_scale = 1.0;
uniform vec2 rect_px = vec2(1080.0, 1075.2);
uniform vec2 rect_origin_px = vec2(-540.0, -537.6);

uniform float px_per_m = 33.75;
uniform float arena_radius_px = 1755.0;
uniform float optic_range_px = 0.0;     // already remapped (ViewMath.map_dist); <= 0 hides the ring
uniform float sweep_phase : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_phase : hint_range(0.0, 1.0) = 0.0;
uniform float sweep_enabled : hint_range(0.0, 1.0) = 1.0;
uniform float pulse_enabled : hint_range(0.0, 1.0) = 1.0;
uniform float density : hint_range(0.0, 1.0) = 1.0;

// radial stand-off remap, mirrors ViewMath.map_dist
uniform float standoff_px = 72.0;
uniform float standoff_near_m = 2.0;
uniform float standoff_span_m = 8.0;

uniform vec4 grid_color : source_color = vec4(0.5412, 0.3725, 0.0, 1.0); // AMBER_DIM #8A5F00
uniform float grid_alpha : hint_range(0.0, 1.0) = 0.35;
uniform float grid_line_px = 1.5;
uniform float ring_spacing_m = 10.0;
uniform float spoke_deg = 30.0;
uniform float grid_inner_px = 175.0;

uniform float sweep_alpha : hint_range(0.0, 1.0) = 0.09;
uniform float sweep_trail_deg = 90.0;
uniform float pulse_alpha : hint_range(0.0, 1.0) = 0.08;
uniform float pulse_max_m = 30.0;
uniform vec4 pulse_color : source_color = vec4(1.0, 0.6902, 0.0, 1.0); // AMBER #FFB000
uniform float optic_alpha : hint_range(0.0, 1.0) = 0.35;

// V1-23: the floor art is drawn at the sprite scale and does not cover the battle rect at every zoom, so the
// floor continues procedurally beyond the art edge: same concentric plate rings and radial seams as
// tools/gen_floor.py (band radii and spoke counts continued past 960), faded in over FLOOR_FADE_ART_PX.
const float FLOOR_FADE_ART_PX = 90.0;
const float SEAM_PX = 3.5;
const float BAND_R[11] = float[11](170.0, 250.0, 312.0, 440.0, 540.0, 640.0, 800.0, 960.0, 1120.0, 1280.0, 1440.0);
const float BAND_N[12] = float[12](1.0, 12.0, 16.0, 20.0, 24.0, 28.0, 32.0, 36.0, 40.0, 44.0, 48.0, 48.0);
const vec3 BAND_TONE[12] = vec3[12](
	vec3(0.0235, 0.0314, 0.0471), vec3(0.0510, 0.0667, 0.0902), vec3(0.0392, 0.0510, 0.0706),
	vec3(0.0471, 0.0627, 0.0863), vec3(0.0353, 0.0471, 0.0627), vec3(0.0431, 0.0588, 0.0784),
	vec3(0.0314, 0.0431, 0.0588), vec3(0.0353, 0.0471, 0.0627), vec3(0.0314, 0.0431, 0.0588),
	vec3(0.0353, 0.0471, 0.0627), vec3(0.0314, 0.0431, 0.0588), vec3(0.0353, 0.0471, 0.0627));
const vec3 SEAM_COLOR = vec3(0.0157, 0.0235, 0.0314);

vec3 proc_floor(float ra, float ang) {
	int bi = 0;
	float ring_d = 100000.0;
	for (int i = 0; i < 11; i++) {
		if (ra >= BAND_R[i]) {
			bi = i + 1;
		}
		if (i > 0) {
			ring_d = min(ring_d, abs(ra - BAND_R[i]));
		}
	}
	float step_rad = 6.2831853 / BAND_N[bi];
	float sd = abs(fract(ang / step_rad + 0.5) - 0.5) * step_rad * ra;
	float seam = max(1.0 - smoothstep(SEAM_PX * 0.5, SEAM_PX * 0.5 + 1.5, ring_d),
		(1.0 - smoothstep(SEAM_PX * 0.5, SEAM_PX * 0.5 + 1.5, sd)) * step(1.0, float(bi)));
	return mix(BAND_TONE[bi], SEAM_COLOR, seam * 0.9);
}

float aa_line(float d_px, float width_px) {
	return 1.0 - smoothstep(width_px * 0.5, width_px * 0.5 + 1.0, d_px);
}

float map_dist_m(float dist_m) {
	float t = clamp(1.0 - (dist_m - standoff_near_m) / standoff_span_m, 0.0, 1.0);
	return dist_m * px_per_m + standoff_px * t;
}

void fragment() {
	vec2 d = rect_origin_px + UV * rect_px;
	float r = length(d);
	float ang = atan(d.y, d.x);

	vec2 art_uv = (d / art_scale + art_center) / art_size;
	vec3 base = texture(floor_tex, art_uv).rgb;
	vec2 art_px = art_uv * art_size;
	float edge_art = min(min(art_px.x, art_size.x - art_px.x), min(art_px.y, art_size.y - art_px.y));
	float art_w = smoothstep(0.0, FLOOR_FADE_ART_PX, edge_art);
	if (art_w < 1.0) {
		base = mix(proc_floor(length(d) / art_scale, ang), base, art_w);
	}

	// polar grid; ring radii >= 10 m are unaffected by the stand-off remap
	float ring_px = ring_spacing_m * px_per_m;
	float rd = abs(fract(r / ring_px + 0.5) - 0.5) * ring_px;
	float rings = aa_line(rd, grid_line_px);
	float step_rad = radians(spoke_deg);
	float sd = abs(fract(ang / step_rad + 0.5) - 0.5) * step_rad * r;
	float spokes = aa_line(sd, grid_line_px) * 0.6;
	float inner = smoothstep(grid_inner_px * art_scale, grid_inner_px * art_scale + 60.0, r);
	float outer = 1.0 - smoothstep(rect_px.y * 0.55, rect_px.y * 0.9, r) * 0.6;
	float inside = 1.0 - smoothstep(arena_radius_px - 2.0, arena_radius_px, r);
	float grid = max(rings, spokes) * inner * outer * inside * grid_alpha * density;
	vec3 light = grid_color.rgb * grid;

	// radar sweep: leading edge at sweep angle, trail behind it
	float sweep_ang = sweep_phase * 6.2831853 - 3.1415927;
	float behind = mod(sweep_ang - ang, 6.2831853);
	float k = clamp(1.0 - behind / radians(sweep_trail_deg), 0.0, 1.0);
	float sweep = k * k * inner * (1.0 - smoothstep(rect_px.y * 0.6, rect_px.y * 0.95, r));
	sweep += aa_line(behind * r, 2.0) * 0.5 * inner * step(behind, 0.2);
	light += grid_color.rgb * sweep * sweep_alpha * sweep_enabled;

	// range-ring pulse every 4 s from Cinder to pulse_max_m (fades with density)
	float pr = map_dist_m(pulse_phase * pulse_max_m);
	float fade = (1.0 - pulse_phase) * (1.0 - pulse_phase);
	light += pulse_color.rgb * aa_line(abs(r - pr), 3.0) * fade * inner * pulse_alpha * density * pulse_enabled;

	// optic range ring
	light += pulse_color.rgb * aa_line(abs(r - optic_range_px), 2.0) * optic_alpha * step(0.5, optic_range_px);

	COLOR = vec4(base + light, 1.0);
}
