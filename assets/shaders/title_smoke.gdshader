shader_type canvas_item;
// IRON STATIC title smoke (M3-25, design 11 section 2.1): one cheap fbm layer (value noise, 3 octaves) on a
// ColorRect. Three of these (different speeds, tints, bands) make the smoke; LOW uses one.
// `blend_premul_alpha`: rgb is premultiplied and `additive` (0..1) moves weight from alpha into pure addition, so
// the same shader draws dark alpha smoke (additive 0) and amber-lit haze (additive near 1).
// `u_time` is driven by the CPU so reduce motion can freeze the noise at a fixed offset (static smoke).
render_mode blend_premul_alpha, unshaded;

uniform vec2 rect_px = vec2(1080.0, 1200.0);
uniform float u_time = 0.0;
uniform vec2 drift = vec2(0.012, -0.004);     // noise-space units per second (x wind, y rise)
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


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}


float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return v / 0.875;
}


void fragment() {
	float aspect = rect_px.x / rect_px.y;
	vec2 p = vec2(UV.x * aspect * 0.7, UV.y) * noise_scale + drift * u_time;
	float n = fbm(p);
	float m = smoothstep(edge_lo, edge_hi, n);
	float band = smoothstep(0.0, fade_top, UV.y) * (1.0 - smoothstep(1.0 - fade_bottom, 1.0, UV.y));
	float a = m * density * band;
	float warm = exp(-pow((UV.y - warm_y) * 2.6, 2.0)) * (0.35 + 0.65 * n) * warm_amount;
	// lit edges: the thin rim of each billow catches the warm light
	float rim = smoothstep(edge_lo, edge_lo + 0.08, n) * (1.0 - smoothstep(edge_lo + 0.08, edge_lo + 0.22, n));
	vec3 rgb = mix(col_dark.rgb, col_warm.rgb, clamp(warm + rim * warm_amount * 0.7, 0.0, 1.0));
	COLOR = vec4(rgb * a, a * (1.0 - additive));
}
