shader_type canvas_item;
// IRON STATIC style frame: enemy sprite + baked additive glow sheet, composited in one draw.
// Art bible 4.3 / 6.2. Works on a Sprite2D/CanvasItem (uniforms) and on a MultiMeshInstance2D
// (set use_instance_custom = true and enable custom data on the MultiMesh).
//
// Output is PREMULTIPLIED: rgb = body.rgb * body.a + glow.rgb * glow.a * glow_strength, a = body.a.
// So glow adds light where the body is transparent and on top of it, in one blend.
// Imported SVG textures are straight alpha (premult_alpha=false), hence the multiplications here.
//
// Layout of INSTANCE_CUSTOM (when use_instance_custom is true):
//   x = hit flash 0..1 (1 at the hit, the CPU decays it to 0 over 90 ms)
//   y = glow/body frame index (float; rounded down)
//   z = spawn-in progress 0..1 (only read when use_spawn_in is true; 1 = fully spawned)
//   w = free (animation phase offset in seconds, added to TIME for pulses)
render_mode blend_premul_alpha;

// Glow sheet: same cell layout as the body sheet at half size (art bible 4.3).
uniform sampler2D glow_tex : source_color, filter_linear, repeat_disable;
// Body sheet frame count along x, when the sprite shows the WHOLE sheet in UV 0..1 (no hframes).
// Leave at 1 for Sprite2D with hframes/region (UV already addresses one cell) and for boss_hulk
// (one body cell).
uniform int body_frames : hint_range(1, 8) = 1;
// Glow sheet frame count along x. 1 = glow cells align with the body UVs (every enemy except the
// boss). >1 = boss mode: UV 0..1 is ONE body cell and the glow sheet holds glow_frames cells.
uniform int glow_frames : hint_range(1, 8) = 1;
// Uniform fallbacks (used when use_instance_custom is false).
uniform float frame : hint_range(0.0, 7.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float spawn_in : hint_range(0.0, 1.0) = 1.0;
uniform bool use_instance_custom = false;
uniform bool use_spawn_in = false;
// Hit flash color and cap (art bible 6.2: walker/boss cap 0.6 so heavy units keep their shape).
uniform vec3 flash_color : source_color = vec3(1.0, 0.93, 0.82);
uniform float flash_cap : hint_range(0.0, 1.0) = 1.0;
// Glow multiplier (also the LOW tier switch: 0 = body only) and the slow breathing pulse.
uniform float glow_strength : hint_range(0.0, 3.0) = 1.0;
uniform float pulse_amount : hint_range(0.0, 0.5) = 0.04;
uniform float pulse_hz : hint_range(0.0, 8.0) = 0.83;
// Colorblind hook (art bible 3.2): multiplies the glow color. (1,1,1) = default palette.
uniform vec3 tint_hostile : source_color = vec3(1.0, 1.0, 1.0);

varying flat vec4 v_custom;
varying vec4 v_mod; // node/instance modulate (COLOR in fragment is already multiplied by the texture)

void vertex() {
	v_mod = COLOR;
	v_custom = vec4(0.0);
	if (use_instance_custom) {
		v_custom = INSTANCE_CUSTOM;
		if (use_spawn_in) {
			// scale 0.6 -> 1.0 while spawning (art bible 4.5 states)
			VERTEX *= mix(0.6, 1.0, clamp(INSTANCE_CUSTOM.z, 0.0, 1.0));
		}
	}
}

void fragment() {
	float f_flash = use_instance_custom ? v_custom.x : flash;
	float f_frame = use_instance_custom ? v_custom.y : frame;
	float f_spawn = 1.0;
	if (use_spawn_in) {
		f_spawn = use_instance_custom ? v_custom.z : spawn_in;
	}
	float phase = use_instance_custom ? v_custom.w : 0.0;

	vec2 body_uv = UV;
	if (body_frames > 1) {
		float bi = floor(mod(f_frame, float(body_frames)));
		body_uv = vec2((bi + UV.x) / float(body_frames), UV.y);
	}
	vec2 glow_uv = UV;
	if (glow_frames > 1) {
		float gi = floor(mod(f_frame, float(glow_frames)));
		glow_uv = vec2((gi + UV.x) / float(glow_frames), UV.y);
	} else if (body_frames > 1) {
		glow_uv = body_uv;
	}

	vec4 body = texture(TEXTURE, body_uv);
	vec4 glow = texture(glow_tex, glow_uv);

	float pulse = 1.0 + pulse_amount * sin((TIME + phase) * pulse_hz * 6.2831853);
	vec3 body_pm = body.rgb * body.a;
	float fl = clamp(f_flash, 0.0, 1.0) * flash_cap;
	body_pm = mix(body_pm, flash_color * body.a, fl);
	vec3 glow_pm = glow.rgb * glow.a * tint_hostile * (glow_strength * pulse);
	// the flash also lifts the glow a little so a flashing unit does not look dimmer
	glow_pm *= 1.0 + 0.5 * fl;

	// v_mod is the node/instance modulate (alpha = fade, rgb = tint); apply it premultiplied.
	vec3 mod_rgb = v_mod.rgb;
	float mod_a = v_mod.a * f_spawn;
	COLOR = vec4((body_pm * mod_rgb + glow_pm) * mod_a, body.a * mod_a);
}
