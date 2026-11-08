class_name TestAudioSlots
extends GdUnitTestSuite

## AudioSlots loader (A1-03): parsing (incl. a BOM-prefixed CSV), defaults, missing files, the real table.

const MINI_CSV: String = (
	"# comment\n"
	+ "id,file,bus,volume_db,pitch_var,voice_cap,cooldown_ms\n"
	+ "sfx_a,sfx/nope_not_here.wav,SFX,-6.5,0.03,6,35\n"
	+ "res,,UI,0,0,0,-5\n"
	+ "music_x,music/x.ogg,Music,-3,9,1,0\n"
)


func before_test() -> void:
	AudioSlots.reset()
	AudioSlots.log_errors = false


func after_test() -> void:
	AudioSlots.log_errors = true
	AudioSlots.reset()


func test_parses_rows_and_clamps() -> void:
	assert_int(AudioSlots.load_text(MINI_CSV)).is_equal(3)
	var a: AudioSlot = AudioSlots.slot("sfx_a")
	assert_bool(a.valid).is_true()
	assert_str(a.bus).is_equal("SFX")
	assert_float(a.volume_db).is_equal(-6.5)
	assert_float(a.pitch_var).is_equal(0.03)
	assert_int(a.voice_cap).is_equal(6)
	assert_int(a.cooldown_ms).is_equal(35)
	var r: AudioSlot = AudioSlots.slot("res")
	assert_bool(r.is_reserved()).is_true()
	assert_int(r.voice_cap).is_equal(1)
	assert_int(r.cooldown_ms).is_equal(0)
	var m: AudioSlot = AudioSlots.slot("music_x")
	assert_bool(m.is_music()).is_true()
	assert_float(m.pitch_var).is_equal(0.5)


func test_bom_prefixed_csv_parses() -> void:
	var text: String = String.chr(0xFEFF) + MINI_CSV
	assert_int(AudioSlots.load_text(text)).is_equal(3)
	assert_bool(AudioSlots.has("sfx_a")).is_true()
	assert_int(AudioSlots.error_count).is_equal(0)


func test_unknown_slot_and_missing_file_do_not_crash() -> void:
	@warning_ignore("return_value_discarded")
	AudioSlots.load_text(MINI_CSV)
	assert_bool(AudioSlots.slot("nope").valid).is_false()
	assert_object(AudioSlots.stream("sfx_a")).is_null()
	assert_object(AudioSlots.stream("res")).is_null()
	assert_int(AudioSlots.error_count).is_equal(3)


func test_duplicate_id_is_an_error() -> void:
	var text: String = "id,file,bus,volume_db,pitch_var,voice_cap,cooldown_ms\na,,SFX,0,0,1,0\na,,SFX,0,0,1,0\n"
	assert_int(AudioSlots.load_text(text)).is_equal(1)
	assert_int(AudioSlots.error_count).is_equal(1)


func test_real_table_every_file_loads() -> void:
	assert_int(AudioSlots.ids().size()).is_greater_equal(16)
	for sid: String in AudioSlots.ids():
		var s: AudioSlot = AudioSlots.slot(sid)
		assert_str(s.bus).is_not_empty()
		assert_object(AudioSlots.stream(sid)).is_not_null()
	assert_int(AudioSlots.error_count).is_equal(0)
	assert_bool(AudioSlots.has("sfx_laser_shot")).is_true()
	assert_bool(AudioSlots.has("sfx_upgrade_buy")).is_true()
