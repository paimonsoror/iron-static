class_name DiskSaveFs
extends SaveFs
## `SaveFs` on the device disk (M3-02). Relative paths resolve under `root` (default `user://save/`),
## which is created on first write. Windows `DirAccess.rename` onto an existing file fails, so rename
## removes the target first; `SaveStore.load` tolerates that window (bak or tmp still hold the data).

var _root: String


func _init(root: String = "user://save/") -> void:
	_root = root if root.ends_with("/") else root + "/"


func read(path: String) -> PackedByteArray:
	var p: String = _full(path)
	if not FileAccess.file_exists(p):
		return PackedByteArray()
	var f: FileAccess = FileAccess.open(p, FileAccess.READ)
	if f == null:
		return PackedByteArray()
	var b: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	return b


func write(path: String, bytes: PackedByteArray) -> bool:
	if DirAccess.make_dir_recursive_absolute(_root) != OK:
		return false
	var f: FileAccess = FileAccess.open(_full(path), FileAccess.WRITE)
	if f == null:
		return false
	var ok: bool = f.store_buffer(bytes)
	f.flush()
	f.close()
	return ok and FileAccess.get_open_error() == OK


func rename(from: String, to: String) -> bool:
	var src: String = _full(from)
	var dst: String = _full(to)
	if not FileAccess.file_exists(src):
		return false
	if FileAccess.file_exists(dst) and DirAccess.remove_absolute(dst) != OK:
		return false
	return DirAccess.rename_absolute(src, dst) == OK


func remove(path: String) -> bool:
	var p: String = _full(path)
	if not FileAccess.file_exists(p):
		return false
	return DirAccess.remove_absolute(p) == OK


func exists(path: String) -> bool:
	return FileAccess.file_exists(_full(path))


func _full(path: String) -> String:
	return _root + path
