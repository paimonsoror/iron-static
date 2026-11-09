class_name TestSaveSchema
extends GdUnitTestSuite
## Schema document, fixtures and the shape guard (M3-04, v2 M4-06). Fixtures are signed with the built-in key.

const FIXTURE_JSON: String = "res://tests/fixtures/save_v%d.json"
const FIXTURE_SIGNED: String = "res://tests/fixtures/save_v%d_signed.sav"
## Profile keys that hold free-form dictionaries (not compared key by key).
const FREE_FORM: Array[String] = ["foundry", "best_wave", "best_wave_by_mode", "settings"]


func before_test() -> void:
	SaveKey.reset()


func _load_fixture(version: int) -> Dictionary:
	var f: FileAccess = FileAccess.open(FIXTURE_JSON % version, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	return SaveSchema.parse_raw(text.to_utf8_buffer())


func _keys(d: Dictionary) -> Array:
	var k: Array = d.keys()
	k.sort()
	return k


func test_a_fixture_exists_for_every_version() -> void:
	for n: int in range(1, SaveSchema.CURRENT + 1):
		assert_bool(FileAccess.file_exists(FIXTURE_JSON % n)).is_true()
		assert_bool(_load_fixture(n).is_empty()).is_false()


func test_shape_guard_document_and_profile_keys_match_fixture() -> void:
	var fix: Dictionary = _load_fixture(SaveSchema.CURRENT)
	var fresh: Dictionary = SaveSchema.document_from_profile(PlayerProfile.fresh(1, "dev"))
	assert_array(_keys(fresh)).is_equal(_keys(fix))
	assert_int(SaveSchema.version_of(fix)).is_equal(SaveSchema.CURRENT)
	var fp: Dictionary = fresh["profile"]
	var xp: Dictionary = fix["profile"]
	var known_in_fixture: Dictionary = {}
	var extras: int = 0
	for k: Variant in xp.keys():
		if k is String and PlayerProfile.KNOWN_KEYS.has(k):
			known_in_fixture[k] = xp[k]
		else:
			extras += 1
	assert_int(extras).is_greater(0)  # the fixture keeps an unknown key (round trip)
	assert_array(_keys(fp)).is_equal(_keys(known_in_fixture))
	for key: String in FREE_FORM:
		assert_bool(xp.has(key)).is_true()
		assert_bool(xp[key] is Dictionary).is_true()
	assert_bool(fix["runs_stats"] is Dictionary).is_true()


func test_fixture_settings_carry_every_known_key() -> void:
	var fix: Dictionary = _load_fixture(SaveSchema.CURRENT)
	var xp: Dictionary = fix["profile"]
	var st: Dictionary = xp["settings"]
	# M4-23 keys are optional on read and absent from the v2 fixture on purpose (no schema bump).
	var later: Array[String] = ["haptics", "colorblind", "high_contrast"]
	for key: String in PlayerSettings.KNOWN_KEYS:
		assert_bool(st.has(key) or later.has(key)).is_true()


func test_every_fixture_loads_through_the_chain_with_valid_invariants() -> void:
	for n: int in range(1, SaveSchema.CURRENT + 1):
		var fix: Dictionary = _load_fixture(n)
		var res: Dictionary = SaveSchema.upgrade(fix, SaveSchema.version_of(fix))
		assert_bool(res["ok"]).is_true()
		var doc: Dictionary = res["doc"]
		assert_int(SaveSchema.version_of(doc)).is_equal(SaveSchema.CURRENT)
		var p: PlayerProfile = SaveSchema.profile_from_document(doc)
		assert_int(p.load_errors.size()).is_equal(0)
		assert_int(p.flux).is_greater_equal(0)
		for id: Variant in p.foundry.keys():
			var level: int = p.foundry[id]
			assert_int(level).is_greater(0)
		assert_bool(p.data.is_zero()).is_false()


func test_fixture_v1_values() -> void:
	var p: PlayerProfile = SaveSchema.profile_from_document(_load_fixture(1))
	assert_str(p.data.to_text()).is_equal("1.5e12")
	assert_int(p.best_wave_s1()).is_equal(14)
	assert_int(p.foundry.size()).is_equal(4)
	assert_bool(p.extra.has("future_flag")).is_true()
	var d: Dictionary = p.to_dict()
	assert_bool(d.has("future_flag")).is_true()


func _load_signed(version: int) -> LoadResult:
	var f: FileAccess = FileAccess.open(FIXTURE_SIGNED % version, FileAccess.READ)
	assert_object(f).is_not_null()
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	var fs: MemorySaveFs = MemorySaveFs.new()
	fs.files["profile.sav"] = bytes
	var store: SaveStore = SaveStore.new(fs, "profile", SaveCodec.MAGIC_PROFILE, SaveSchema.CURRENT)
	return store.load()


func test_signed_fixtures_decode_through_store_and_equal_json() -> void:
	for n: int in range(1, SaveSchema.CURRENT + 1):
		var r: LoadResult = _load_signed(n)
		assert_int(r.status).is_equal(LoadResult.Status.OK)
		assert_int(r.schema).is_equal(n)
		var from_sav: PlayerProfile = SaveSchema.profile_from_document(SaveSchema.parse_raw(r.raw))
		var from_json: PlayerProfile = SaveSchema.profile_from_document(_load_fixture(n))
		assert_dict(from_sav.to_dict()).is_equal(from_json.to_dict())


func test_signed_v1_fixture_migrates_to_v2_timed_record() -> void:
	var r: LoadResult = _load_signed(1)
	var up: Dictionary = SaveSchema.upgrade(SaveSchema.parse_raw(r.raw), r.schema)
	assert_bool(up["ok"]).is_true()
	var doc: Dictionary = up["doc"]
	var p: PlayerProfile = SaveSchema.profile_from_document(doc)
	assert_int(p.best_wave_of_mode("timed", 1)).is_equal(14)
	assert_int(p.best_wave_of_mode("purge", 1)).is_equal(0)
	assert_array(p.modes_unlocked).is_equal(["timed"])


func test_fixture_v2_values() -> void:
	var p: PlayerProfile = SaveSchema.profile_from_document(_load_fixture(2))
	assert_int(p.load_errors.size()).is_equal(0)
	assert_int(p.best_wave_s1()).is_equal(22)
	assert_int(p.best_wave_of_mode("purge", 1)).is_equal(35)
	assert_array(p.modes_unlocked).is_equal(["timed", "purge"])
	assert_str(p.last_mode).is_equal("purge")
	assert_bool(p.extra.has("future_flag")).is_true()


func test_schema_3_document_is_too_new() -> void:
	var doc: Dictionary = SaveSchema.document_from_profile(PlayerProfile.fresh(1, "dev"))
	var fs: MemorySaveFs = MemorySaveFs.new()
	var store: SaveStore = SaveStore.new(fs, "profile", SaveCodec.MAGIC_PROFILE, SaveSchema.CURRENT)
	fs.files["profile.sav"] = SaveCodec.encode(SaveCodec.MAGIC_PROFILE, 3, SaveSchema.raw_from_document(doc))
	assert_int(store.load().status).is_equal(LoadResult.Status.TOO_NEW)


func test_document_round_trip_through_raw() -> void:
	var p: PlayerProfile = SaveSchema.profile_from_document(_load_fixture(1))
	var doc: Dictionary = SaveSchema.document_from_profile(p)
	var back: PlayerProfile = SaveSchema.profile_from_document(SaveSchema.parse_raw(SaveSchema.raw_from_document(doc)))
	assert_dict(back.to_dict()).is_equal(p.to_dict())
	assert_int(back.load_errors.size()).is_equal(0)


func test_bad_documents_do_not_crash() -> void:
	assert_bool(SaveSchema.parse_raw("not json".to_utf8_buffer()).is_empty()).is_true()
	assert_bool(SaveSchema.parse_raw("[1,2]".to_utf8_buffer()).is_empty()).is_true()
	var p: PlayerProfile = SaveSchema.profile_from_document({"schema_version": 1})
	assert_int(p.load_errors.size()).is_greater(0)
	assert_int(SaveSchema.version_of({"schema_version": "x"})).is_equal(0)
