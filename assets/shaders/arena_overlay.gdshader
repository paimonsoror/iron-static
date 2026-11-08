shader_type canvas_item;
// IRON STATIC arena overlay: scanlines, vignette and the low-HP red haze in ONE premultiplied full-rect pass that
// draws above the sprites (art bible 6.7, 6.8). rgb adds light (haze), alpha darkens (scanlines, vignette).
// Not a post-process: no screen texture read, no blur, so sprites stay crisp; scanlines are 6% by default.
// `low_hp` is the final haze intensity, already eased and heartbeat-modulated on the CPU (HeartbeatModel, ArenaFxParams).
render_mode blend_premul_alpha, unshaded;

uniform vec2 rect_px = vec2(1080.0, 1075.2);
uniform float scan_alpha : hint_range(0.0, 0.3) = 0.06;   // 0 = off (tier, reduce motion, user setting)
uniform float scan_period_px = 4.0;
uniform float scan_line_px = 2.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.2;
uniform float low_hp : hint_range(0.0, 1.0) = 0.0;        // 0.25..0.45 band 3, 0.08 band 2, see ArenaFxParams
uniform vec4 haze_color : source_color = vec4(1.0, 0.2314, 0.1882, 1.0); // CRITICAL #FF3B30


void fragment() {
	vec2 pos = UV * rect_px;
	vec2 vuv = (UV - 0.5) * 2.0;
	float edge = smoothstep(0.35, 1.25, length(vuv * vec2(1.0, 0.85)));
	vec3 haze = haze_color.rgb * edge * low_hp * 1.2;
	float sl = step(mod(pos.y, scan_period_px), scan_line_px);
	float dark = clamp(sl * scan_alpha + edge * vignette, 0.0, 0.9);
	COLOR = vec4(haze, dark);
}
