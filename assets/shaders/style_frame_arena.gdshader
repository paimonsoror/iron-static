shader_type canvas_item;
// IRON STATIC style frame: arena light + overlay in ONE full-rect pass (art bible 6.7, 6.8).
// Put it on a ColorRect covering the battle rect (1080 x 1344), above the arena_floor sprite.
// Premultiplied output: rgb adds light (grid, sweep, pulse, optic ring, low-HP haze),
// a darkens (scanlines, vignette). One draw, no textures, no geometry, all analytic.
//
// Units: pixels of the 1080-wide base layout. Set rect_px to the ColorRect size; center_px is
// Cinder's position inside the rect (default = rect center). px_per_m is the camera scale
// (32 m view = 33.75 px/m, 38 m = 28.4 px/m). Rings are drawn at ring_spacing_m multiples.
render_mode blend_premul_alpha, unshaded;

uniform vec2 rect_px = vec2(1080.0, 1344.0);
uniform vec2 center_px = vec2(540.0, 672.0);
uniform float px_per_m = 33.75;

// (a) polar grid
uniform vec4 grid_color : source_color = vec4(0.5412, 0.3725, 0.0, 1.0); // AMBER_DIM #8A5F00
uniform float grid_alpha : hint_range(0.0, 1.0) = 0.35;
uniform float grid_line_px = 1.5;
uniform float ring_spacing_m = 10.0;
uniform float spoke_deg = 30.0;
uniform float grid_inner_px = 175.0;   // no grid under the Cinder pad
uniform float grid_fade : hint_range(0.0, 1.0) = 1.0; // drop to 0 above 100 enemies (07 s5.3)

// (b) radar sweep
uniform vec4 sweep_color : source_color = vec4(0.5412, 0.3725, 0.0, 1.0);
uniform float sweep_alpha : hint_range(0.0, 1.0) = 0.09;
uniform float sweep_period_s = 8.0;
uniform float sweep_trail_deg = 90.0;
uniform float sweep_enabled : hint_range(0.0, 1.0) = 1.0; // 0 in LOW tier

// (c) range ring pulse
uniform float pulse_alpha : hint_range(0.0, 1.0) = 0.08;
uniform float pulse_period_s = 4.0;
uniform float pulse_max_m = 30.0;
uniform vec4 pulse_color : source_color = vec4(1.0, 0.6902, 0.0, 1.0); // AMBER #FFB000

// (d) optic range ring
uniform float optic_range_m = 24.0;
uniform float optic_alpha : hint_range(0.0, 1.0) = 0.35;

// (e) scanlines (battlefield only; 0 = off, 0.06 = default, 0.03 = low)
uniform float scan_alpha : hint_range(0.0, 0.3) = 0.06;
uniform float scan_period_px = 4.0;
uniform float scan_line_px = 2.0;

// (f) vignette and low-HP haze
uniform float vignette : hint_range(0.0, 1.0) = 0.2;
uniform float lowhp : hint_range(0.0, 1.0) = 0.0;       // 0 = fine, 1 = band 3
uniform vec4 haze_color : source_color = vec4(1.0, 0.2314, 0.1882, 1.0); // CRITICAL #FF3B30
uniform float heartbeat_hz = 1.2;
uniform bool reduce_motion = false;

float aa_line(float d_px, float width_px) {
	// d_px: distance to the line centre in px, antialiased with a 1 px ramp
	return 1.0 - smoothstep(width_px * 0.5, width_px * 0.5 + 1.0, d_px);
}

float heart(float t) {
	// lub-dub: two soft pulses per beat
	float p = fract(t * heartbeat_hz);
	float a = exp(-pow((p - 0.04) / 0.07, 2.0));
	float b = 0.7 * exp(-pow((p - 0.26) / 0.08, 2.0));
	return clamp(a + b, 0.0, 1.0);
}

void fragment() {
	vec2 pos = UV * rect_px;
	vec2 d = pos - center_px;
	float r = length(d);
	float ang = atan(d.y, d.x); // -PI..PI, 0 = +x, clockwise on screen (y down)

	// ---- (a) polar grid with soft radial falloff
	float ring_px = ring_spacing_m * px_per_m;
	float rd = abs(fract(r / ring_px + 0.5) - 0.5) * ring_px;
	float rings = aa_line(rd, grid_line_px);
	float step_rad = radians(spoke_deg);
	float sd = abs(fract(ang / step_rad + 0.5) - 0.5) * step_rad * r;
	float spokes = aa_line(sd, grid_line_px) * 0.6;
	float inner = smoothstep(grid_inner_px, grid_inner_px + 60.0, r);
	float outer = 1.0 - smoothstep(rect_px.y * 0.55, rect_px.y * 0.9, r) * 0.6;
	float grid = max(rings, spokes) * inner * outer * grid_alpha * grid_fade;
	vec3 light = grid_color.rgb * grid;

	// ---- (b) radar sweep: leading edge at sweep angle, trail fading behind it (counter-clockwise on screen)
	float t = reduce_motion ? 0.0 : TIME;
	float sweep_ang = fract(t / sweep_period_s) * 6.2831853 - 3.1415927;
	float behind = mod(sweep_ang - ang, 6.2831853); // 0 at the edge, grows into the trail
	float trail = radians(sweep_trail_deg);
	float k = clamp(1.0 - behind / trail, 0.0, 1.0);
	float sweep = k * k * inner * (1.0 - smoothstep(rect_px.y * 0.6, rect_px.y * 0.95, r));
	sweep += aa_line(behind * r, 2.0) * 0.5 * inner * step(behind, 0.2); // thin bright leading edge
	light += sweep_color.rgb * sweep * sweep_alpha * sweep_enabled * (reduce_motion ? 0.0 : 1.0);

	// ---- (c) range ring pulse (every pulse_period_s, 0 -> pulse_max_m, fades out)
	float pp = fract(t / pulse_period_s);
	float pr = pp * pulse_max_m * px_per_m;
	float pulse = aa_line(abs(r - pr), 3.0) * (1.0 - pp) * (1.0 - pp) * inner;
	light += pulse_color.rgb * pulse * pulse_alpha * grid_fade * (reduce_motion ? 0.0 : 1.0);

	// ---- (d) optic range ring
	float orp = optic_range_m * px_per_m;
	float optic = aa_line(abs(r - orp), 2.0);
	light += pulse_color.rgb * optic * optic_alpha;

	// ---- (f) low-HP haze: red edges pulsing as a double beat (reduce motion = static 0.3)
	vec2 vuv = (UV - 0.5) * 2.0;
	float edge = smoothstep(0.35, 1.25, length(vuv * vec2(1.0, 0.85)));
	float beat = reduce_motion ? 0.3 : (0.25 + 0.2 * heart(TIME));
	vec3 haze = haze_color.rgb * edge * beat * lowhp * 0.6;
	light += haze;

	// ---- (e) scanlines + (f) vignette darken
	float sl = step(mod(pos.y, scan_period_px), scan_line_px);
	float dark = sl * scan_alpha;
	dark += edge * vignette;
	dark = clamp(dark, 0.0, 0.9);

	COLOR = vec4(light, dark);
}
