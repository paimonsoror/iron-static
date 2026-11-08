shader_type canvas_item;
// IRON STATIC particle ring (V1-13, art bible 6.3; hardened V1-26): one MultiMesh of 1x1 quads, every particle
// integrated analytically from its spawn data, so the CPU writes a particle once. Data layout and precision
// budget = src/view/particle_pack.gd.
// V1-26: no bit-packing. A GPU that runs the old floor/shift decode at fp16/mediump (PowerVR C-Series through
// ANGLE/Vulkan) drew colour and size garbage as huge yellow glows. The instance carries only its float32 transform
// (origin = spawn position); every other field is a plain float32 read with texelFetch from the RGBAF texture
// u_data, 3 texels per particle:
//   texel 0: r g b a (tint, peak alpha)   texel 1: vx vy s0 s1 (px/s, px)   texel 2: birth life kind (s, s, int)
// All decoding is highp and every decoded value is clamped, so a bad value can never fill the screen.
// Blend: additive. The smoke pool uses the same code with blend_mix (ParticleRenderer.make_mix_shader replaces the
// render_mode line).
render_mode blend_add;

// Largest legitimate particle size in px (ParticlePack.SIZE_MAX); anything bigger is data corruption.
const highp float SIZE_CAP = 1800.0;
// Largest legitimate velocity component in px/s (ParticlePack.VEL_MAX).
const highp float VEL_CAP = 1024.0;
// Per-particle data, one row of RGBAF, never filtered.
uniform highp sampler2D u_data : filter_nearest, repeat_disable;

// Sim time in seconds on the wrapping 32 s clock (frozen while paused, scaled by game speed: it is sim time).
uniform highp float u_now = 0.0;
// Per kind: uv rect (x, y, w, h) of the fx_sheet cell.
uniform highp vec4 u_cells[32];
// Per kind: x = quad height / width, y = fade-in fraction of life, z = fade-out power, w = drag (1/s).
uniform highp vec4 u_kind[32];
// Per kind: x = spin amplitude rad/s (random sign and size per particle), y = 1 aligns the quad to the velocity.
uniform highp vec4 u_kind2[32];

varying highp vec2 v_uv;
varying highp vec4 v_col;

void vertex() {
	v_col = vec4(0.0);
	v_uv = vec2(0.0);
	int base = INSTANCE_ID * 3;
	highp vec4 d_col = texelFetch(u_data, ivec2(base, 0), 0);
	highp vec4 d_mot = texelFetch(u_data, ivec2(base + 1, 0), 0);
	highp vec4 d_time = texelFetch(u_data, ivec2(base + 2, 0), 0);
	highp float birth = d_time.x;
	highp float life = d_time.y;
	highp float age = mod(u_now - birth + 8.0, 32.0) - 8.0;
	highp float t = age / max(life, 0.0001);
	if (life <= 0.0 || age < 0.0 || t >= 1.0) {
		// dead, not born yet or finished: collapse the quad (no fragments)
		VERTEX = vec2(0.0);
	} else {
		int kind = clamp(int(floor(d_time.z + 0.5)), 0, 31);
		highp vec3 rgb = clamp(d_col.rgb, 0.0, 1.0);
		highp float alpha = clamp(d_col.a, 0.0, 1.0);
		highp vec2 vel = clamp(d_mot.xy, vec2(-VEL_CAP), vec2(VEL_CAP));
		highp vec4 kp = u_kind[kind];
		highp vec4 kq = u_kind2[kind];
		highp float drag = kp.w;
		highp float travel = age;
		if (drag > 0.01) {
			travel = (1.0 - exp(-drag * age)) / drag;
		}
		highp vec2 disp = vel * travel;
		// start angle and spin from a hash of the slot and its birth: variety without per-particle data
		highp float h1 = fract(sin(float(INSTANCE_ID) * 12.9898 + birth * 78.233) * 43758.5453);
		highp float h2 = fract(sin(float(INSTANCE_ID) * 39.3468 + birth * 11.135) * 24634.6345);
		highp float ang = h1 * 6.2831853 + (h2 * 2.0 - 1.0) * kq.x * age;
		if (kq.y > 0.5) {
			ang = atan(vel.y, vel.x);
		}
		highp float ease_t = 1.0 - (1.0 - t) * (1.0 - t);
		highp float size = clamp(mix(d_mot.z, d_mot.w, ease_t), 0.0, SIZE_CAP);
		highp vec2 q = VERTEX * vec2(size, size * kp.x);
		highp float cs = cos(ang);
		highp float sn = sin(ang);
		VERTEX = vec2(q.x * cs - q.y * sn, q.x * sn + q.y * cs) + disp;

		highp float fade_in = kp.y > 0.0 ? clamp(t / kp.y, 0.0, 1.0) : 1.0;
		highp float fade_out = pow(1.0 - t, kp.z);
		v_col = vec4(rgb, clamp(alpha * fade_in * fade_out, 0.0, 1.0));
		highp vec4 cell = u_cells[kind];
		v_uv = cell.xy + UV * cell.zw;
	}
}

void fragment() {
	vec4 tex = texture(TEXTURE, v_uv);
	COLOR = clamp(vec4(v_col.rgb * tex.rgb, v_col.a * tex.a), 0.0, 1.0);
}
