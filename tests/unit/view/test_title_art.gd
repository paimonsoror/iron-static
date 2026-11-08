extends GdUnitTestSuite
## M3-26 title production art: slot rows load through ArtSlots, the three hero silhouettes differ, every frame swaps in.

const FRAMES: Array[String] = ["vanguard", "bulwark", "striker"]
const TITLE_SLOTS: Array[String] = [
	"title_sky_glow",
	"title_spires_far",
	"title_hulks_mid",
	"title_ridge_near",
	"title_ridge_front",
	"title_logo_iron",
	"title_logo_static",
	"title_sil_vanguard",
	"title_sil_vanguard_glow",
	"title_sil_bulwark",
	"title_sil_bulwark_glow",
	"title_sil_striker",
	"title_sil_striker_glow",
	"title_sil_locked_vanguard",
	"title_sil_locked_bulwark",
	"title_sil_locked_striker",
]


func before_test() -> void:
	ArtSlots.reset()


func after_test() -> void:
	ArtSlots.reset()


func test_title_slots_load_with_spec_sizes() -> void:
	for sid: String in TITLE_SLOTS:
		assert_bool(ArtSlots.has(sid)).override_failure_message("missing slot " + sid).is_true()
		var art: ArtSlot = ArtSlots.slot(sid)
		var tex: Texture2D = ArtSlots.texture(sid)
		assert_bool(tex != ArtSlots.placeholder()).override_failure_message("placeholder for " + sid).is_true()
		assert_int(tex.get_width()).override_failure_message("width of " + sid).is_equal(art.sheet_size.x)
		assert_int(tex.get_height()).override_failure_message("height of " + sid).is_equal(art.sheet_size.y)
	assert_int(ArtSlots.error_count).is_equal(0)


func _stats(frame: String) -> Vector3:
	var tex: Texture2D = TitleFrameArt.tex("sil_" + frame)
	var img: Image = tex.get_image()
	var minp := Vector2i(img.get_width(), img.get_height())
	var maxp := Vector2i(-1, -1)
	var covered: int = 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a >= 10.0 / 255.0:
				covered += 1
				minp = Vector2i(mini(minp.x, x), mini(minp.y, y))
				maxp = Vector2i(maxi(maxp.x, x), maxi(maxp.y, y))
	var w: float = float(maxp.x - minp.x + 1)
	var h: float = float(maxp.y - minp.y + 1)
	return Vector3(w / h, w * h, float(covered))


func test_silhouettes_differ_by_aspect_or_area() -> void:
	var s: Dictionary = {}
	for fid: String in FRAMES:
		s[fid] = _stats(fid)
	for i: int in FRAMES.size():
		for j: int in range(i + 1, FRAMES.size()):
			var a: Vector3 = s[FRAMES[i]]
			var b: Vector3 = s[FRAMES[j]]
			var d_aspect: float = absf(a.x - b.x) / maxf(a.x, b.x)
			var d_area: float = absf(a.y - b.y) / maxf(a.y, b.y)
			var d_cover: float = absf(a.z - b.z) / maxf(a.z, b.z)
			var msg: String = (
				"%s vs %s: aspect %.2f area %.2f cover %.2f" % [FRAMES[i], FRAMES[j], d_aspect, d_area, d_cover]
			)
			assert_bool(maxf(d_aspect, d_area) >= 0.12).override_failure_message(msg).is_true()


func test_stage_swaps_frames() -> void:
	var st := TitleFrameStage.new()
	add_child(st)
	st.build()
	auto_free(st)
	for fid: String in FRAMES:
		st.set_frame(fid)
		assert_str(st.frame_id_shown).is_equal(fid)
