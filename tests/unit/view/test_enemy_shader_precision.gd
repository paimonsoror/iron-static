class_name TestEnemyShaderPrecision
extends GdUnitTestSuite
## V1-29: the enemy shader must not read MultiMesh instance COLOR / CUSTOM (garbage on PowerVR via ANGLE once they
## change every frame); it reads float32 texels of u_inst with texelFetch, in highp, with every field clamped.

const SHADER_PATH: String = "res://assets/shaders/enemy_sprite.gdshader"


func _code() -> String:
	return (load(SHADER_PATH) as Shader).code


## Shader code without // comments, so documentation cannot trip the checks.
func _code_only() -> String:
	var lines := PackedStringArray()
	for line: String in _code().split("\n"):
		lines.append(line.get_slice("//", 0))
	return "\n".join(lines)


func test_shader_reads_no_instance_custom_or_instance_color() -> void:
	var code: String = _code_only()
	assert_bool(code.contains("INSTANCE_CUSTOM")).is_false()
	assert_bool(code.contains("= COLOR;")).is_false()
	assert_bool(code.contains("v_mod")).is_false()
	# the only COLOR use is the fragment output
	assert_int(code.count("COLOR")).is_equal(1)
	assert_bool(code.contains("COLOR = vec4(")).is_true()


func test_shader_fetches_the_data_texel_by_instance_id_in_vertex() -> void:
	var code: String = _code_only()
	assert_bool(code.contains("uniform highp sampler2D u_inst : filter_nearest")).is_true()
	assert_bool(code.contains("texelFetch(u_inst, ivec2(INSTANCE_ID, 0), 0)")).is_true()
	var vertex_body: String = code.substr(
		code.find("void vertex()"), code.find("void fragment()") - code.find("void vertex()")
	)
	assert_bool(vertex_body.contains("texelFetch")).is_true()


func test_shader_declares_highp_and_clamps_every_field() -> void:
	var code: String = _code_only()
	for needed: String in [
		"varying flat highp vec4 v_custom",
		"highp vec4 d = texelFetch",
		"highp float flash = clamp(d.x, 0.0, 1.0)",
		"highp float frame = clamp(floor(d.y + 0.5), 0.0, FRAME_MAX)",
		"highp float spawn = clamp(d.z, 0.0, 1.0)",
		"highp float phase = clamp(d.w, 0.0, PHASE_MAX)",
		"const highp float FRAME_MAX",
		"const highp float PHASE_MAX",
	]:
		assert_bool(code.contains(needed)).override_failure_message("missing: " + needed).is_true()
	assert_bool(code.contains("clamp(v_custom.z, 0.0, 1.0)")).is_true()  # spawn alpha stays bounded in fragment


func test_frame_clamp_covers_the_largest_sheet() -> void:
	var m: RegExMatch = RegEx.create_from_string("FRAME_MAX = ([0-9]+)[.]0").search(_code())
	assert_object(m).is_not_null()
	for slot: String in ViewMath.ENEMY_SLOTS + ["bolt"]:
		assert_int(ArtSlots.slot(slot).frames - 1).is_less_equal(m.get_string(1).to_int())
