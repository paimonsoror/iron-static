extends Node
## Autoload `Log`: prefixed console logging with a 200-line ring buffer.

const MAX_LINES: int = 200

var lines: PackedStringArray = PackedStringArray()


func info(msg: String) -> void:
	_emit("[INFO] " + msg)


func warn(msg: String) -> void:
	_emit("[WARN] " + msg)


func error(msg: String) -> void:
	_emit("[ERROR] " + msg)


func _emit(line: String) -> void:
	print(line)
	# append()/resize() return values (warned as discarded); append_array() returns void.
	lines.append_array(PackedStringArray([line]))
	if lines.size() > MAX_LINES:
		lines.remove_at(0)
