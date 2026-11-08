class_name TestArtSlots
extends GdUnitTestSuite

## ArtSlots loader (V1-02): table rows, frame rects, glow pairing, visual scale, placeholder on missing files.

const MINI_CSV: String = (
	"# comment line\n"
	+ "slot,file,glow_file,glow_slot,sheet_w,sheet_h,cell_x,cell_y,cell_w,cell_h,frames,pivot_x,pivot_y,fps,"
	+ "body_radius_px,texel_per_px,visual_scale,aspect,margin,blend,family,status,notes\n"
	+ "a,nope_not_here.svg,,a_glow,200,50,10,5,50,40,4,25,20,8,12,2,0.5,1.5,4,normal,enemy,ready,x\n"
	+ "a_glow,nope_not_here_glow.svg,,,100,25,5,2,25,20,4,12,10,8,,1,0.5,,6,add,enemy,ready,y\n"
	+ "r,,,,64,64,0,0,64,64,1,32,32,,,2,,,0,normal,enemy,reserved,z\n"
)


func before_test() -> void:
	ArtSlots.reset()
	ArtSlots.log_errors = false


func after_test() -> void:
	ArtSlots.log_errors = true
	ArtSlots.reset()


func test_table_loads_and_has_known_slots() -> void:
	assert_int(ArtSlots.ids().size()).is_greater(90)
	assert_bool(ArtSlots.has("skitter")).is_true()
	assert_bool(ArtSlots.has("cinder_core")).is_true()
	assert_bool(ArtSlots.has("fx_beam_strip")).is_true()
	assert_bool(ArtSlots.has("icon_cur_scrap")).is_true()
	assert_bool(ArtSlots.has("ui_panel_plate")).is_true()
	assert_int(ArtSlots.error_count).is_equal(0)


func test_every_ready_row_loads_a_real_texture() -> void:
	var checked: int = 0
	for sid: String in ArtSlots.ids():
		var art: ArtSlot = ArtSlots.slot(sid)
		if art.status != "ready":
			continue
		var tex: Texture2D = ArtSlots.texture(sid)
		(
			assert_bool(tex != ArtSlots.placeholder())
			. override_failure_message("slot %s fell back to placeholder" % sid)
			. is_true()
		)
		assert_int(tex.get_width()).override_failure_message("slot %s sheet width" % sid).is_equal(art.sheet_size.x)
		assert_int(tex.get_height()).override_failure_message("slot %s sheet height" % sid).is_equal(art.sheet_size.y)
		checked += 1
	assert_int(checked).is_greater(60)
	assert_int(ArtSlots.error_count).is_equal(0)


func test_rows_stay_inside_their_sheet_and_glow_pairs_resolve() -> void:
	for sid: String in ArtSlots.ids():
		var art: ArtSlot = ArtSlots.slot(sid)
		if art.is_reserved():
			continue
		var last: Rect2 = art.frame_rect(art.frames - 1)
		(
			assert_bool(last.end.x <= float(art.sheet_size.x) and last.end.y <= float(art.sheet_size.y))
			. override_failure_message("slot %s exceeds its sheet" % sid)
			. is_true()
		)
		if not art.glow_slot.is_empty():
			(
				assert_bool(ArtSlots.has(art.glow_slot))
				. override_failure_message("slot %s: glow_slot missing" % sid)
				. is_true()
			)
			assert_bool(ArtSlots.slot(art.glow_slot).additive).is_true()
	assert_int(ArtSlots.error_count).is_equal(0)


func test_skitter_frame_three_uv() -> void:
	var art: ArtSlot = ArtSlots.slot("skitter")
	assert_int(art.frames).is_equal(4)
	var uv: Rect2 = ArtSlots.frames_uv(art, 3)
	assert_float(uv.position.x).is_equal_approx(0.75, 0.00001)
	assert_float(uv.position.y).is_equal_approx(0.0, 0.00001)
	assert_float(uv.size.x).is_equal_approx(0.25, 0.00001)
	assert_float(uv.size.y).is_equal_approx(1.0, 0.00001)
	assert_that(ArtSlots.frame_rect(art, 3)).is_equal(Rect2(576, 0, 192, 192))
	assert_that(ArtSlots.frame_rect(art, 99)).is_equal(Rect2(576, 0, 192, 192))
	assert_that(art.pivot_frac()).is_equal(Vector2(0.5, 0.5))


func test_walker_visual_scale_and_sprite_scale() -> void:
	var walker: ArtSlot = ArtSlots.slot("walker")
	assert_float(walker.visual_scale).is_equal_approx(0.8, 0.00001)
	assert_float(walker.sprite_scale()).is_equal_approx(0.4, 0.00001)
	assert_float(ArtSlots.slot("skitter").sprite_scale()).is_equal_approx(0.5, 0.00001)
	assert_float(ArtSlots.slot("boss_hulk").sprite_scale()).is_equal_approx(1.0 / 1.5, 0.00001)
	assert_float(ArtSlots.slot("icon_cur_scrap").sprite_scale()).is_equal_approx(1.0, 0.00001)


func test_glow_pairing_is_half_size_and_additive() -> void:
	var body: ArtSlot = ArtSlots.slot("lancer")
	var glow: ArtSlot = ArtSlots.glow_of("lancer")
	assert_bool(glow.valid).is_true()
	assert_bool(glow.additive).is_true()
	assert_that(glow.sheet_size).is_equal(Vector2i(432, 112))
	assert_that(glow.cell_size * 2).is_equal(body.cell_size)
	assert_float(glow.texel_per_px).is_equal_approx(body.texel_per_px * 0.5, 0.00001)
	var boss_glow: ArtSlot = ArtSlots.glow_of("boss_hulk")
	assert_int(boss_glow.frames).is_equal(4)
	assert_that(boss_glow.cell_size).is_equal(Vector2i(320, 320))
	assert_bool(ArtSlots.glow_of("cinder_shadow").valid).is_false()
	assert_int(ArtSlots.error_count).is_equal(0)


func test_reserved_rows_have_no_file() -> void:
	var art: ArtSlot = ArtSlots.slot("aegis_node")
	assert_bool(art.is_reserved()).is_true()
	assert_str(art.file).is_empty()
	assert_bool(ArtSlots.texture("aegis_node") == ArtSlots.placeholder()).is_true()


func test_missing_slot_is_invalid_and_missing_file_is_magenta() -> void:
	var count: int = ArtSlots.load_text(MINI_CSV, "mini")
	assert_int(count).is_equal(3)
	var missing: ArtSlot = ArtSlots.slot("does_not_exist")
	assert_bool(missing.valid).is_false()
	assert_int(ArtSlots.error_count).is_equal(1)
	var tex: Texture2D = ArtSlots.texture("a")
	assert_bool(tex == ArtSlots.placeholder()).is_true()
	assert_int(tex.get_width()).is_equal(1)
	var px: Color = tex.get_image().get_pixel(0, 0)
	assert_bool(px.is_equal_approx(Color(1, 0, 1, 1))).is_true()
	assert_int(ArtSlots.error_count).is_equal(2)
	assert_str(ArtSlots.last_error).contains("nope_not_here.svg")
	var at: AtlasTexture = ArtSlots.atlas("a", 2)
	assert_that(at.region).is_equal(Rect2(110, 5, 50, 40))


func test_parse_of_a_custom_table() -> void:
	ArtSlots.load_text(MINI_CSV, "mini")
	var a: ArtSlot = ArtSlots.slot("a")
	assert_that(a.sheet_size).is_equal(Vector2i(200, 50))
	assert_that(a.cell_pos).is_equal(Vector2i(10, 5))
	assert_that(a.frame_rect(1)).is_equal(Rect2(60, 5, 50, 40))
	assert_float(a.fps).is_equal(8.0)
	assert_float(a.visual_scale).is_equal(0.5)
	assert_float(a.aspect).is_equal(1.5)
	assert_int(a.margin).is_equal(4)
	assert_bool(a.additive).is_false()
	assert_bool(ArtSlots.glow_of("a").additive).is_true()
	assert_float(ArtSlots.slot("r").visual_scale).is_equal(1.0)


func test_bad_tables_never_throw() -> void:
	assert_int(ArtSlots.load_text("slot,file\na,b,c\n", "bad")).is_equal(0)
	assert_int(ArtSlots.error_count).is_equal(1)
	assert_int(ArtSlots.load_text("slot,file\na,x.svg\na,y.svg\n", "dup")).is_equal(1)
	assert_int(ArtSlots.error_count).is_equal(2)


func test_palette_consts_are_in_the_lint_palette() -> void:
	var rules_text: String = FileAccess.get_file_as_string("res://tools/art_rules.json")
	var parsed: Variant = JSON.parse_string(rules_text)
	assert_bool(parsed is Dictionary).is_true()
	var rules: Dictionary = parsed
	var pal: Array = rules["palette"]
	var script: GDScript = Palette
	var checked: int = 0
	var consts: Dictionary = script.get_script_constant_map()
	for key: Variant in consts:
		var value: Variant = consts[key]
		if value is Color:
			var c: Color = value
			if c.a < 1.0:
				continue
			var hex: String = "#" + c.to_html(false).to_upper()
			(
				assert_bool(pal.has(hex))
				. override_failure_message("Palette.%s %s missing in art_rules.json" % [key, hex])
				. is_true()
			)
			checked += 1
	assert_int(checked).is_greater(40)
