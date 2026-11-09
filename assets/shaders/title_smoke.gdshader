shader_type canvas_item;
// IRON STATIC title smoke (M3-25, design 11 section 2.1): one cheap fbm layer (value noise, 3 octaves) on a
// ColorRect. Three of these (different speeds, tints, bands) make the smoke; LOW uses one.
// `blend_premul_alpha`: rgb is premultiplied and `additive` (0..1) moves weight from alpha into pure addition, so
// the same shader draws dark alpha smoke (additive 0) and amber-lit haze (additive near 1).
// `u_time` is driven by the CPU so reduce motion can freeze the noise at a fixed offset (static smoke).
render_mode blend_premul_alpha, unshaded;

uniform highp vec2 rect_px = vec2(1080.0, 1200.0);
uniform highp float u_time = 0.0;
uniform highp vec2 drift = vec2(0.012, -0.004);     // noise-space units per second (x wind, y rise)
uniform float noise_scale : hint_range(0.5, 8.0) = 2.4;
uniform float density : hint_range(0.0, 1.0) = 0.6;
uniform float additive : hint_range(0.0, 1.0) = 0.0;
uniform float edge_lo : hint_range(0.0, 1.0) = 0.35;   // noise threshold where smoke starts
uniform float edge_hi : hint_range(0.0, 1.0) = 0.85;   // noise value where smoke is full
uniform vec4 col_dark : source_color = vec4(0.05, 0.035, 0.03, 1.0);
uniform vec4 col_warm : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform float warm_y : hint_range(0.0, 1.0) = 0.7;      // vertical position (uv) of the warm light
uniform float warm_amount : hint_range(0.0, 1.0) = 0.6;
uniform float fade_top : hint_range(0.01, 1.0) = 0.25;   // uv.y span where the band fades in from the top
uniform float fade_bottom : hint_range(0.01, 1.0) = 0.25; // uv.y span where it fades out at the bottom
// High band (M3-26): above uv.y = hi_end the same rect draws a second, streakier drifting band (0 = off). It is
// thinned around `hi_hole_y` so the logo plate stays legible and lit from below (`hi_warm_y`). One fbm per pixel.
uniform float hi_end : hint_range(0.0, 1.0) = 0.0;
uniform float hi_density : hint_range(0.0, 1.0) = 0.7;
uniform float hi_scale : hint_range(0.5, 8.0) = 2.6;
uniform highp vec2 hi_drift = vec2(0.01, -0.002);
uniform float hi_edge_lo : hint_range(0.0, 1.0) = 0.36;
uniform float hi_edge_hi : hint_range(0.0, 1.0) = 0.7;
uniform vec4 hi_dark : source_color = vec4(0.045, 0.035, 0.035, 1.0);
uniform vec4 hi_warm : source_color = vec4(0.95, 0.5, 0.18, 1.0);
uniform float hi_warm_y : hint_range(0.0, 1.0) = 0.5;
uniform float hi_hole_y : hint_range(0.0, 1.0) = 0.3;
uniform float hi_hole_h : hint_range(0.01, 0.5) = 0.1;
uniform float hi_hole_amount : hint_range(0.0, 1.0) = 0.5;


// Every noise step is highp: Godot's Compatibility renderer defaults fragment floats to mediump on Android, and
// the fp16 hash/fract collapsed the value noise into hard rectangular blocks on the device (desktop is always fp32).
highp float hash21(highp vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


highp float vnoise(highp vec2 p) {
	highp vec2 i = floor(p);
	highp vec2 f = fract(p);
	highp vec2 u = f * f * (3.0 - 2.0 * f);
	highp float a = hash21(i);
	highp float b = hash21(i + vec2(1.0, 0.0));
	highp float c = hash21(i + vec2(0.0, 1.0));
	highp float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}


highp float fbm(highp vec2 p) {
	highp float v = 0.0;
	highp float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return v / 0.875;
}


void fragment() {
	highp float aspect = rect_px.x / rect_px.y;
	if (UV.y < hi_end) {
		// streaky: stretched along x, slow
		highp vec2 hp = vec2(UV.x * aspect * 0.28, UV.y * 1.1) * hi_scale + hi_drift * u_time;
		highp float hn = fbm(hp);
		float hm = smoothstep(hi_edge_lo, hi_edge_hi, hn);
		float hole = 1.0 - hi_hole_amount * exp(-pow((UV.y - hi_hole_y) / hi_hole_h, 2.0));
		float hband = smoothstep(0.0, 0.05, UV.y) * (1.0 - smoothstep(hi_end - 0.1, hi_end, UV.y));
		float ha = hm * hi_density * hband * hole;
		float hwarm = exp(-pow((UV.y - hi_warm_y) * 5.0, 2.0)) * (0.3 + 0.7 * hn);
		float hrim = smoothstep(hi_edge_lo, hi_edge_lo + 0.08, hn) * (1.0 - smoothstep(hi_edge_lo + 0.08, hi_edge_lo + 0.22, hn));
		vec3 hrgb = mix(hi_dark.rgb, hi_warm.rgb, clamp(hwarm * 0.6 + hrim * 0.5, 0.0, 1.0));
		COLOR = vec4(hrgb * ha, ha * (1.0 - additive * 0.5));
	} else {
		highp vec2 p = vec2(UV.x * aspect * 0.7, UV.y) * noise_scale + drift * u_time;
		highp float n = fbm(p);
		float m = smoothstep(edge_lo, edge_hi, n);
		float band = smoothstep(hi_end, hi_end + fade_top, UV.y) * (1.0 - smoothstep(1.0 - fade_bottom, 1.0, UV.y));
		float a = m * density * band;
		float warm = exp(-pow((UV.y - warm_y) * 2.6, 2.0)) * (0.35 + 0.65 * n) * warm_amount;
		// lit edges: the thin rim of each billow catches the warm light
		float rim = smoothstep(edge_lo, edge_lo + 0.08, n) * (1.0 - smoothstep(edge_lo + 0.08, edge_lo + 0.22, n));
		vec3 rgb = mix(col_dark.rgb, col_warm.rgb, clamp(warm + rim * warm_amount * 0.7, 0.0, 1.0));
		COLOR = vec4(rgb * a, a * (1.0 - additive));
	}
}
