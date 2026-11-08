class_name MemorySaveFs
extends SaveFs
## In-memory `SaveFs` with fault injection (tests).
##
## `fail_at(n)`: the n-th mutating operation (write/rename/remove, 1-based, counted from now) returns
## false and changes nothing. `power_loss_after(n)`: operations 1..n complete, every later mutating
## operation silently does nothing and returns false (the process died). Reads always work.

var files: Dictionary = {}  # path -> PackedByteArray
var ops: int = 0
var _fail_at: int = -1
var _loss_after: int = -1


func fail_at(n: int) -> void:
	ops = 0
	_fail_at = n
	_loss_after = -1


func power_loss_after(n: int) -> void:
	ops = 0
	_loss_after = n
	_fail_at = -1


func clear_faults() -> void:
	_fail_at = -1
	_loss_after = -1


func read(path: String) -> PackedByteArray:
	if not files.has(path):
		return PackedByteArray()
	var b: PackedByteArray = files[path]
	return b.duplicate()


func write(path: String, bytes: PackedByteArray) -> bool:
	if not _allow():
		return false
	files[path] = bytes.duplicate()
	return true


func rename(from: String, to: String) -> bool:
	if not _allow():
		return false
	if not files.has(from):
		return false
	files[to] = files[from]
	files.erase(from)
	return true


func remove(path: String) -> bool:
	if not _allow():
		return false
	return files.erase(path)


func exists(path: String) -> bool:
	return files.has(path)


func _allow() -> bool:
	ops += 1
	if _loss_after >= 0 and ops > _loss_after:
		return false
	if _fail_at >= 0 and ops == _fail_at:
		return false
	return true
