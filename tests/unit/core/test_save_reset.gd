class_name TestSaveReset
extends GdUnitTestSuite
## SaveService.reset_profile (M3-30, Q66): old files renamed to `*.reset` byte for byte, settings kept, never deletes.

var fs: MemorySaveFs
var clock: FakeClock


func before_test() -> void:
	SaveKey.reset()
	fs = MemorySaveFs.new()
	clock = FakeClock.new(1000)


func _b64(path: String) -> String:
	var b: PackedByteArray = fs.files[path]
	return Marshalls.raw_to_base64(b)


func _played() -> SaveService:
	var s := SaveService.new(fs, clock, "dev1")
	@warning_ignore("return_value_discarded")
	s.load_profile()
	s.profile.settings = {"sfx": 0.25, "muted": true}
	@warning_ignore("return_value_discarded")
	s.bank_run(RunSummary.make(1, 9, BigNum.parse("250"), 1800))
	@warning_ignore("return_value_discarded")
	s.bank_run(RunSummary.make(2, 11, BigNum.parse("100"), 1800))  # a second save makes a .bak
	return s


func test_reset_archives_the_exact_old_bytes_and_starts_fresh_with_the_settings() -> void:
	var s: SaveService = _played()
	assert_bool(fs.exists("profile.bak")).is_true()
	var live: PackedByteArray = fs.files["profile.sav"]
	var bak: PackedByteArray = fs.files["profile.bak"]
	assert_bool(s.reset_profile()).is_true()
	assert_bool(fs.exists("profile.sav")).is_false()
	assert_bool(fs.exists("profile.bak")).is_false()
	assert_str(_b64("profile.sav.reset")).is_equal(Marshalls.raw_to_base64(live))
	assert_str(_b64("profile.bak.reset")).is_equal(Marshalls.raw_to_base64(bak))
	assert_bool(s.profile.has_progress()).is_false()
	assert_bool(s.profile.data.is_zero()).is_true()
	assert_int(s.profile.best_wave_s1()).is_equal(0)
	assert_str(s.profile.frame_selected).is_equal("vanguard")
	var sfx: float = s.profile.settings["sfx"]
	assert_float(sfx).is_equal(0.25)
	assert_bool(s.profile.settings["muted"]).is_true()
	assert_bool(s.writes_blocked).is_false()
	assert_int(s.last_load_status).is_equal(LoadResult.Status.FRESH)


func test_a_second_reset_never_overwrites_the_first_archive() -> void:
	var s: SaveService = _played()
	var first: PackedByteArray = fs.files["profile.sav"]
	assert_bool(s.reset_profile()).is_true()
	@warning_ignore("return_value_discarded")
	s.bank_run(RunSummary.make(1, 4, BigNum.parse("7"), 600))
	var second: PackedByteArray = fs.files["profile.sav"]
	assert_bool(s.reset_profile()).is_true()
	assert_array(fs.files["profile.sav.reset"]).is_equal(first)
	assert_array(fs.files["profile.sav.reset.1"]).is_equal(second)


func test_reset_archives_the_run_snapshot_files_too() -> void:
	var s: SaveService = _played()
	var snap: String = s.checkpointer.store.live_path()
	fs.files[snap] = PackedByteArray([1, 2, 3])
	assert_bool(s.reset_profile()).is_true()
	assert_bool(fs.exists(snap)).is_false()
	assert_array(fs.files[snap + ".reset"]).is_equal(PackedByteArray([1, 2, 3]))


func test_reset_is_refused_while_writes_are_blocked() -> void:
	fs.files["profile.sav"] = PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
	var s := SaveService.new(fs, clock, "dev1")
	@warning_ignore("return_value_discarded")
	s.load_profile()
	assert_bool(s.writes_blocked).is_true()
	assert_bool(s.reset_profile()).is_false()
	assert_bool(fs.exists("profile.sav")).is_true()


func test_profile_reset_helper_saves_the_fresh_profile_with_the_settings() -> void:
	var s: SaveService = _played()
	assert_bool(ProfileReset.run(s)).is_true()
	assert_bool(fs.exists("profile.sav")).is_true()
	var back := SaveService.new(fs, clock, "dev1")
	@warning_ignore("return_value_discarded")
	back.load_profile()
	assert_bool(back.profile.has_progress()).is_false()
	assert_bool(back.profile.settings["muted"]).is_true()
	assert_bool(ProfileReset.run(null)).is_false()
