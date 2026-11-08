class_name TestSaveStore
extends GdUnitTestSuite
## SaveStore on MemorySaveFs (M3-02).

const MAGIC: String = "ISAV"
const MAXS: int = 3

var fs: MemorySaveFs
var store: SaveStore


func before_test() -> void:
	fs = MemorySaveFs.new()
	store = SaveStore.new(fs, "profile", MAGIC, MAXS)


func _p(text: String) -> PackedByteArray:
	return text.to_utf8_buffer()


func _text(r: LoadResult) -> String:
	return r.raw.get_string_from_utf8()


func _flip(path: String, pos: int) -> void:
	var b: PackedByteArray = fs.files[path]
	b[pos] = b[pos] ^ 1
	fs.files[path] = b


func test_save_then_load_ok() -> void:
	assert_bool(store.save(1, _p("one"))).is_true()
	var r: LoadResult = store.load()
	assert_int(r.status).is_equal(LoadResult.Status.OK)
	assert_str(r.source).is_equal("live")
	assert_int(r.schema).is_equal(1)
	assert_str(_text(r)).is_equal("one")
	assert_bool(fs.exists("profile.tmp")).is_false()


func test_second_save_keeps_backup_of_first() -> void:
	assert_bool(store.save(1, _p("one"))).is_true()
	assert_bool(store.save(1, _p("two"))).is_true()
	var bak: DecodeResult = SaveCodec.decode(MAGIC, fs.read("profile.bak"), MAXS)
	assert_str(bak.raw.get_string_from_utf8()).is_equal("one")
	assert_str(_text(store.load())).is_equal("two")


func test_power_loss_at_every_step_never_corrupt() -> void:
	# Mutating ops of a save: 1 write tmp, 2 rename live->bak, 3 rename tmp->live (verify is a read).
	for n: int in range(0, 4):
		var f: MemorySaveFs = MemorySaveFs.new()
		var s: SaveStore = SaveStore.new(f, "profile", MAGIC, MAXS)
		assert_bool(s.save(1, _p("old"))).is_true()
		assert_bool(s.save(1, _p("old2"))).is_true()  # live + bak both present
		f.power_loss_after(n)
		var ok: bool = s.save(1, _p("new"))
		assert_bool(ok).is_equal(n >= 3)
		f.clear_faults()
		var r: LoadResult = s.load()
		assert_bool(r.status == LoadResult.Status.OK or r.status == LoadResult.Status.RECOVERED).is_true()
		var t: String = _text(r)
		assert_bool(t == "old2" or t == "new" or t == "old").is_true()


func test_power_loss_on_first_save() -> void:
	for n: int in range(0, 4):
		var f: MemorySaveFs = MemorySaveFs.new()
		var s: SaveStore = SaveStore.new(f, "profile", MAGIC, MAXS)
		f.power_loss_after(n)
		var ok: bool = s.save(1, _p("first"))
		f.clear_faults()
		var r: LoadResult = s.load()
		if n == 0:
			assert_int(r.status).is_equal(LoadResult.Status.FRESH)
		else:
			assert_bool(r.has_data()).is_true()
			assert_str(_text(r)).is_equal("first")
		assert_bool(ok).is_equal(n >= 2)


func test_flipped_live_recovers_from_bak_and_is_not_promoted() -> void:
	assert_bool(store.save(1, _p("one"))).is_true()
	assert_bool(store.save(1, _p("two"))).is_true()
	_flip("profile.sav", 20)
	var r: LoadResult = store.load()
	assert_int(r.status).is_equal(LoadResult.Status.RECOVERED)
	assert_str(r.source).is_equal("bak")
	assert_str(_text(r)).is_equal("one")
	assert_bool(store.save(1, _p("three"))).is_true()
	var bak: DecodeResult = SaveCodec.decode(MAGIC, fs.read("profile.bak"), MAXS)
	assert_str(bak.raw.get_string_from_utf8()).is_equal("one")  # damaged live was not promoted
	assert_str(_text(store.load())).is_equal("three")


func test_both_damaged_is_corrupt_and_nothing_wiped() -> void:
	assert_bool(store.save(1, _p("one"))).is_true()
	assert_bool(store.save(1, _p("two"))).is_true()
	_flip("profile.sav", 20)
	_flip("profile.bak", 20)
	var live_before: PackedByteArray = fs.read("profile.sav")
	var bak_before: PackedByteArray = fs.read("profile.bak")
	var r: LoadResult = store.load()
	assert_int(r.status).is_equal(LoadResult.Status.CORRUPT)
	assert_bool(fs.exists("profile.sav") and fs.exists("profile.bak")).is_true()
	assert_bool(fs.read("profile.sav") == live_before).is_true()
	assert_bool(fs.read("profile.bak") == bak_before).is_true()


func test_no_files_is_fresh() -> void:
	assert_int(store.load().status).is_equal(LoadResult.Status.FRESH)


func test_too_new_is_reported_and_never_deleted() -> void:
	var newer: SaveStore = SaveStore.new(fs, "profile", MAGIC, 9)
	assert_bool(newer.save(9, _p("future"))).is_true()
	var before: PackedByteArray = fs.read("profile.sav")
	var r: LoadResult = store.load()
	assert_int(r.status).is_equal(LoadResult.Status.TOO_NEW)
	assert_int(r.found_schema).is_equal(9)
	assert_bool(fs.read("profile.sav") == before).is_true()
	# The caller may still choose to save; the old file then becomes the backup.
	assert_bool(store.save(1, _p("mine"))).is_true()
	assert_bool(fs.exists("profile.bak")).is_true()


func test_failing_write_or_rename_keeps_previous_state() -> void:
	assert_bool(store.save(1, _p("one"))).is_true()
	for n: int in range(1, 4):
		fs.fail_at(n)
		var ok: bool = store.save(1, _p("two"))
		fs.clear_faults()
		assert_bool(ok).is_false()
		var r: LoadResult = store.load()
		assert_bool(r.has_data()).is_true()
		assert_bool(_text(r) == "one" or _text(r) == "two").is_true()
		assert_bool(store.save(1, _p("one"))).is_true()  # back to a known state
	fs.fail_at(1)
	assert_bool(store.save(1, _p("x"))).is_false()


func test_quarantine_keeps_bytes_and_never_overwrites() -> void:
	assert_bool(store.save(1, _p("one"))).is_true()
	assert_bool(store.save(1, _p("two"))).is_true()
	var live: PackedByteArray = fs.read("profile.sav")
	var bak: PackedByteArray = fs.read("profile.bak")
	assert_bool(store.quarantine()).is_true()
	assert_bool(fs.exists("profile.sav") or fs.exists("profile.bak")).is_false()
	assert_bool(fs.read("profile.corrupt") == live).is_true()
	assert_bool(fs.read("profile.corrupt.1") == bak).is_true()
	assert_int(store.load().status).is_equal(LoadResult.Status.FRESH)
	# Second round: the first quarantine survives.
	assert_bool(store.save(1, _p("three"))).is_true()
	var third: PackedByteArray = fs.read("profile.sav")
	assert_bool(store.quarantine()).is_true()
	assert_bool(fs.read("profile.corrupt") == live).is_true()
	assert_bool(fs.read("profile.corrupt.2") == third).is_true()


func test_remove_all() -> void:
	assert_bool(store.save(1, _p("one"))).is_true()
	assert_bool(store.save(1, _p("two"))).is_true()
	assert_bool(store.remove_all()).is_true()
	assert_int(store.load().status).is_equal(LoadResult.Status.FRESH)


func test_stores_are_independent_by_name() -> void:
	var snap: SaveStore = SaveStore.new(fs, "run_snapshot", "ISNP", MAXS)
	assert_bool(store.save(1, _p("p"))).is_true()
	assert_bool(snap.save(1, _p("s"))).is_true()
	assert_str(_text(store.load())).is_equal("p")
	assert_str(_text(snap.load())).is_equal("s")
	assert_bool(snap.remove_all()).is_true()
	assert_str(_text(store.load())).is_equal("p")
