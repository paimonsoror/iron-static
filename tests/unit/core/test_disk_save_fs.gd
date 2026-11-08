class_name TestDiskSaveFs
extends GdUnitTestSuite
## DiskSaveFs on a throwaway user:// folder (M3-02).

var _dir: String = ""


func before_test() -> void:
	_dir = "user://test_save_%d/" % OS.get_process_id()


func after_test() -> void:
	var d: DirAccess = DirAccess.open(_dir)
	if d != null:
		for f: String in d.get_files():
			var rc: int = DirAccess.remove_absolute(_dir + f)
			assert_int(rc).is_equal(OK)
	var rc2: int = DirAccess.remove_absolute(_dir)
	assert_int(rc2).is_equal(OK)


func test_write_read_rename_over_existing_remove() -> void:
	var fs: DiskSaveFs = DiskSaveFs.new(_dir)
	assert_bool(fs.exists("a.sav")).is_false()
	assert_int(fs.read("a.sav").size()).is_equal(0)
	assert_bool(fs.write("a.tmp", PackedByteArray([1, 2, 3]))).is_true()
	assert_bool(fs.write("a.tmp", PackedByteArray([4, 5]))).is_true()  # truncates
	assert_bool(fs.read("a.tmp") == PackedByteArray([4, 5])).is_true()
	assert_bool(fs.write("a.sav", PackedByteArray([9]))).is_true()
	assert_bool(fs.rename("a.tmp", "a.sav")).is_true()  # replaces the existing target
	assert_bool(fs.read("a.sav") == PackedByteArray([4, 5])).is_true()
	assert_bool(fs.exists("a.tmp")).is_false()
	assert_bool(fs.rename("missing", "b")).is_false()
	assert_bool(fs.remove("a.sav")).is_true()
	assert_bool(fs.remove("a.sav")).is_false()


func test_store_on_disk_round_trip() -> void:
	var store: SaveStore = SaveStore.new(DiskSaveFs.new(_dir), "profile", "ISAV", 1)
	assert_int(store.load().status).is_equal(LoadResult.Status.FRESH)
	assert_bool(store.save(1, "hello".to_utf8_buffer())).is_true()
	assert_bool(store.save(1, "world".to_utf8_buffer())).is_true()
	var r: LoadResult = store.load()
	assert_int(r.status).is_equal(LoadResult.Status.OK)
	assert_str(r.raw.get_string_from_utf8()).is_equal("world")
