shader_type canvas_item;
// IRON STATIC title logo shimmer (M3-25, design 11 section 2.1): a slow diagonal light sweep over the letters plus,
// when the CPU raises `tear` (0.15 s, every few seconds), a horizontal tear (two bands shifted sideways), an
// R/B channel offset and a few static sparkles. Offsets are at most a few percent of the width, so the word
// stays readable. All timing comes from the CPU (`TitleFrameLogo`); reduce motion sets every uniform to 0.
render_mode unshaded;

uniform float sweep : hint_range(-0.5, 1.5) = -0.5;   // position of the light sweep along the diagonal
uniform float sweep_strength : hint_range(0.0, 1.0) = 0.35;
uniform float tear : hint_range(0.0, 1.0) = 0.0;       // glitch envelope
uniform float tear_y = 0.3;                              // band centres (uv.y)
uniform float tear_y2 = 0.7;
uniform float tear_h = 0.035;                            // band half height (uv)
uniform float tear_dx = 0.022;                           // band shift (uv.x), about 21 px on the 960 px logo
uniform float split = 0.006;                             // channel offset (uv.x)
uniform float noise_seed = 0.0;


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


void fragment() {
	vec2 uv = UV;
	float b1 = step(abs(uv.y - tear_y), tear_h);
	float b2 = step(abs(uv.y - tear_y2), tear_h * 0.6);
	vec2 off = vec2((b1 - b2 * 0.7) * tear_dx * tear, 0.0);
	vec2 sp = vec2(split * tear, 0.0);
	vec4 cg = texture(TEXTURE, uv + off);
	vec4 cr = texture(TEXTURE, uv + off + sp);
	vec4 cb = texture(TEXTURE, uv + off - sp);
	float a = max(cg.a, max(cr.a, cb.a));
	vec3 rgb = vec3(cr.r, cg.g, cb.b);
	// diagonal sweep, only over lit letter pixels
	float d = uv.x * 0.75 + uv.y * 0.25 - sweep;
	float s = exp(-d * d * 260.0) * sweep_strength;
	rgb += vec3(1.0, 0.9, 0.7) * s * cg.a;
	// static sparkles inside the letters while tearing
	vec2 cell = floor(uv * vec2(240.0, 100.0));
	float sparkle = step(0.985, hash21(cell + noise_seed)) * tear * cg.a;
	rgb = mix(rgb, vec3(1.0, 0.95, 0.8), sparkle * 0.8);
	COLOR = vec4(rgb, a) * COLOR;
}
