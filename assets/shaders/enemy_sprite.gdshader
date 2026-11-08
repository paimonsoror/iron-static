shader_type canvas_item;
// IRON STATIC enemy sprite (V1-10): body sheet frame + baked additive glow sheet in one draw (art bible 4.3,
// 6.2, 4.5). Used by the MultiMesh of every enemy type and the bolt. Derived from style_frame_enemy.gdshader.
//
// Output is PREMULTIPLIED: rgb = body.rgb * body.a + glow.rgb * glow.a * glow_strength, a = body.a.
// Imported SVG textures are straight alpha, hence the multiplications here.
//
// INSTANCE_CUSTOM (MultiMesh use_custom_data, written by MultiMeshBuffer):
//   x = hit flash 0..1 (CPU decays it over 90 ms)   y = flipbook frame (float, floored in the shader)
//   z = spawn-in 0..1 (1 = spawned; scale 0.6 -> 1.0 and alpha 0 -> 1)   w = phase seed for the glow pulse
render_mode blend_premul_alpha;

// Glow sheet: same cell layout as the body sheet at half size (art bible 4.3).
uniform sampler2D glow_tex : source_color, filter_linear, repeat_disable;
// Body frames along x when the quad UV 0..1 is ONE cell and the sheet holds `body_frames` cells.
uniform int body_frames : hint_range(1, 8) = 1;
// Glow sheet frame count along x. 1 = glow cells align with the body cells (every type but the boss).
// >1 = boss mode: the body is one cell and the glow sheet holds glow_frames cells.
uniform int glow_frames : hint_range(1, 8) = 1;
// Hit flash color and cap (art bible 6.2: heavy units cap lower so they keep their shape).
uniform vec3 flash_color : source_color = vec3(1.0, 0.93, 0.82);
uniform float flash_cap : hint_range(0.0, 1.0) = 0.8;
// Glow multiplier (density ramp, 0 in the LOW tier) and the slow breathing pulse.
uniform float glow_strength : hint_range(0.0, 3.0) = 1.0;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.04;
uniform float pulse_hz : hint_range(0.0, 8.0) = 0.83;
// Colorblind hook (art bible 3.2): multiplies the glow color. (1,1,1) = default palette.
uniform vec3 tint_hostile : source_color = vec3(1.0, 1.0, 1.0);

varying flat vec4 v_custom;
varying vec4 v_mod;

void vertex() {
	v_mod = COLOR;
	v_custom = INSTANCE_CUSTOM;
	VERTEX *= mix(0.6, 1.0, clamp(INSTANCE_CUSTOM.z, 0.0, 1.0));
}

void fragment() {
	float f_frame = v_custom.y;
	vec2 body_uv = UV;
	if (body_frames > 1) {
		float bi = floor(mod(f_frame + 0.5, float(body_frames)));
		body_uv = vec2((bi + UV.x) / float(body_frames), UV.y);
	}
	vec2 glow_uv = UV;
	if (glow_frames > 1) {
		float gi = floor(mod(f_frame + 0.5, float(glow_frames)));
		glow_uv = vec2((gi + UV.x) / float(glow_frames), UV.y);
	} else if (body_frames > 1) {
		glow_uv = body_uv;
	}

	vec4 body = texture(TEXTURE, body_uv);
	vec4 glow = texture(glow_tex, glow_uv);

	float pulse = 1.0 + pulse_amount * sin((TIME + v_custom.w) * pulse_hz * 6.2831853);
	float fl = clamp(v_custom.x, 0.0, 1.0) * flash_cap;
	vec3 body_pm = mix(body.rgb * body.a, flash_color * body.a, fl);
	vec3 glow_pm = glow.rgb * glow.a * tint_hostile * (glow_strength * pulse);
	// the flash also lifts the glow a little so a flashing unit does not look dimmer
	glow_pm *= 1.0 + 0.5 * fl;

	float mod_a = v_mod.a * clamp(v_custom.z, 0.0, 1.0);
	COLOR = vec4((body_pm * v_mod.rgb + glow_pm) * mod_a, body.a * mod_a);
}
