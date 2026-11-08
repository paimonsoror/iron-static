shader_type canvas_item;
// IRON STATIC particle ring (V1-13, art bible 6.3): one MultiMesh of 1x1 quads, every particle integrated
// analytically from its spawn data, so the CPU writes a particle once. Bit layout = src/view/particle_pack.gd.
// Instance COLOR and CUSTOM data arrive as 16-bit halves, so every field is an integer <= 2047:
//   COLOR.r birth (1/64 s, wrapping 32 s clock)   COLOR.g life (7 bits, 1/64 s; 0 = dead) | alpha (4 bits) << 7
//   COLOR.b kind (5 bits) | blue (5 bits) << 5    COLOR.a red (5 bits) | green (5 bits) << 5
//   INSTANCE_CUSTOM  x/y velocity px/s + 1024     z/w size at birth / death in px
// The instance origin (float32 transform) is the spawn position.
// Blend: additive. The smoke pool uses the same code with blend_mix (ParticleRenderer replaces the render_mode line).
render_mode blend_add;

// Sim time in seconds on the wrapping 32 s clock (frozen while paused, scaled by game speed: it is sim time).
uniform float u_now = 0.0;
// Per kind: uv rect (x, y, w, h) of the fx_sheet cell.
uniform vec4 u_cells[32];
// Per kind: x = quad height / width, y = fade-in fraction of life, z = fade-out power, w = drag (1/s).
uniform vec4 u_kind[32];
// Per kind: x = spin amplitude rad/s (random sign and size per particle), y = 1 aligns the quad to the velocity.
uniform vec4 u_kind2[32];

varying vec2 v_uv;
varying vec4 v_col;

void vertex() {
	v_col = vec4(0.0);
	v_uv = vec2(0.0);
	int h_life = int(COLOR.g + 0.5);
	int life_q = h_life & 127;
	float birth = float(int(COLOR.r + 0.5)) / 64.0;
	float age = mod(u_now - birth + 8.0, 32.0) - 8.0;
	float life = float(life_q) / 64.0;
	float t = age / max(life, 0.0001);
	if (life_q == 0 || age < 0.0 || t >= 1.0) {
		// dead, not born yet or finished: collapse the quad (no fragments)
		VERTEX = vec2(0.0);
	} else {
		int h_kb = int(COLOR.b + 0.5);
		int h_rg = int(COLOR.a + 0.5);
		int kind = h_kb & 31;
		vec3 rgb = vec3(float(h_rg & 31), float((h_rg >> 5) & 31), float((h_kb >> 5) & 31)) / 31.0;
		float alpha = float((h_life >> 7) & 15) / 15.0;
		vec2 vel = vec2(INSTANCE_CUSTOM.x - 1024.0, INSTANCE_CUSTOM.y - 1024.0);
		vec4 kp = u_kind[kind];
		vec4 kq = u_kind2[kind];
		float drag = kp.w;
		float travel = age;
		if (drag > 0.01) {
			travel = (1.0 - exp(-drag * age)) / drag;
		}
		vec2 disp = vel * travel;
		// start angle and spin from a hash of the slot and its birth: variety without spending bits
		float h1 = fract(sin(float(INSTANCE_ID) * 12.9898 + birth * 78.233) * 43758.5453);
		float h2 = fract(sin(float(INSTANCE_ID) * 39.3468 + birth * 11.135) * 24634.6345);
		float ang = h1 * 6.2831853 + (h2 * 2.0 - 1.0) * kq.x * age;
		if (kq.y > 0.5) {
			ang = atan(vel.y, vel.x);
		}
		float ease_t = 1.0 - (1.0 - t) * (1.0 - t);
		float size = mix(INSTANCE_CUSTOM.z, INSTANCE_CUSTOM.w, ease_t);
		vec2 q = VERTEX * vec2(size, size * kp.x);
		float cs = cos(ang);
		float sn = sin(ang);
		VERTEX = vec2(q.x * cs - q.y * sn, q.x * sn + q.y * cs) + disp;

		float fade_in = kp.y > 0.0 ? clamp(t / kp.y, 0.0, 1.0) : 1.0;
		float fade_out = pow(1.0 - t, kp.z);
		v_col = vec4(rgb, alpha * fade_in * fade_out);
		vec4 cell = u_cells[kind];
		v_uv = cell.xy + UV * cell.zw;
	}
}

void fragment() {
	vec4 tex = texture(TEXTURE, v_uv);
	COLOR = vec4(v_col.rgb * tex.rgb, v_col.a * tex.a);
}
